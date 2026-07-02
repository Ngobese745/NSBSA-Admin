// Supabase Edge Function — Grace Period End Reminder
//
// Deploy: supabase functions deploy process-grace-period-reminders --no-verify-jwt
// Schedule (09:00 daily via pg_cron):
//   supabase migrations apply (runs 20260702020000_grace_period_reminder_cron.sql)
//
// This function scans loans where grace_period_enabled=true and
// first_payment_date <= today, then sends a one-off "repayments begin"
// notification to each borrower via WhatsApp (WeSenderAPI), SMS (SMSWorx),
// and email (MailerSend queue).  Each notification is logged in the
// reminder_log table to prevent duplicate sends.
//
// Grace period reminders are a one-shot event — once the log entry is
// written for a given loan ref, it is never sent again.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

interface VendorInfo {
  id: string;
  name: string;
  phone: string | null;
  email: string | null;
  whatsapp: string | null;
}

interface GraceLoanRow {
  id: string;
  amount: number;
  monthly_payment: number;
  first_payment_date: string;
  grace_period_months: number;
  status: string;
  vendors: VendorInfo;
}

interface GraceInvoice {
  vendorId: string;
  vendorName: string;
  phone: string;
  email: string;
  whatsapp: string;
  loanRef: string;
  monthlyPayment: number;
  dueDate: string;
  graceMonths: number;
}

function buildGraceEmailHtml(
  name: string,
  ref: string,
  amount: string,
  due: string,
  graceMonths: number,
): string {
  return `<!DOCTYPE html>
<html><head><meta charset="utf-8"><style>
body{font-family:Inter,sans-serif;background:#0A0E14;color:#E6E6E6;margin:0;padding:0}
.container{max-width:600px;margin:40px auto;background:#161B22;border-radius:16px;overflow:hidden;border:1px solid #30363D}
.header{background:#0D1117;padding:40px;text-align:center;border-bottom:2px solid #D4AF37}
.tagline{font-size:12px;color:#D4AF37;letter-spacing:1px;margin-top:10px;text-transform:uppercase}
.content{padding:40px 50px;line-height:1.8;color:#B1BAC4}
.tbl{width:100%;border-collapse:collapse;margin:25px 0;background:#0D1117;border-radius:8px;overflow:hidden;border:1px solid #30363D}
.tbl th,.tbl td{padding:15px 20px;text-align:left;border-bottom:1px solid #1F242D}
.tbl th{color:#8B949E;font-weight:400;font-size:14px;width:40%}
.tbl td{color:#fff;font-weight:700;font-size:14px}
.tbl tr:last-child th,.tbl tr:last-child td{border-bottom:none}
.footer{padding:30px;text-align:center;color:#484F58;font-size:12px;background:#0D1117;border-top:1px solid #30363D}
.badge{display:inline-block;background:#D4AF37;color:#0D1117;padding:6px 16px;border-radius:20px;font-weight:700;font-size:12px;margin-top:12px}
</style></head><body>
<div class="container">
<div class="header"><div class="tagline">NSBSA | Empowering Communities</div><div class="badge">GRACE PERIOD ENDED</div></div>
<div class="content">
<p>Dear <strong>${name}</strong>,</p>
<p>Your loan grace period of <strong>${graceMonths} month${graceMonths > 1 ? "s" : ""}</strong> has ended. Starting now, your monthly repayment instalments begin.</p>
<table class="tbl">
<tr><th>Loan Reference</th><td>${ref}</td></tr>
<tr><th>Monthly Instalment</th><td>R${amount}</td></tr>
<tr><th>First Payment Due</th><td>${due}</td></tr>
</table>
<p>Please arrange payment at your nearest NSBSA branch or via your group representative. Late payments incur a penalty of R59 per month.</p>
</div>
<div class="footer">
<p><strong>Contact NSBSA</strong><br>Email: info@nsbsa.org.za | Phone: 087 107 7524</p>
<p style="font-size:10px;">Automated communication from NSBSA.</p>
</div></div></body></html>`;
}

function graceWhatsAppText(name: string, amount: string, ref: string, due: string, graceMonths: number): string {
  return `Dear ${name}, your ${graceMonths}-month grace period has ended. Your first loan repayment of R${amount} is due on ${due}. Ref: ${ref}. Please pay now to avoid penalties.`;
}

function graceSmsText(amount: string, ref: string, due: string): string {
  return `NSBSA: Grace period ended. Your first loan repayment of R${amount} is due ${due}. Ref: ${ref}. Pay now to avoid penalties.`;
}

async function getApiKey(supabaseUrl: string, serviceKey: string, serviceName: string): Promise<string | null> {
  const res = await fetch(`${supabaseUrl}/rest/v1/api_keys?service_name=eq.${serviceName}&status=eq.active&select=api_key`, {
    headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}` },
  });
  if (!res.ok) return null;
  const rows = await res.json();
  return rows?.[0]?.api_key ?? null;
}

function formatPhone(phone: string): string {
  const cleaned = phone.replace(/\D/g, "");
  if (cleaned.startsWith("0") && cleaned.length === 10) return `27${cleaned.slice(1)}`;
  if (cleaned.startsWith("27") && (cleaned.length === 11 || cleaned.length === 12)) return cleaned;
  return cleaned;
}

async function supabaseInsert(supabaseUrl: string, serviceKey: string, table: string, body: unknown): Promise<Response> {
  return fetch(`${supabaseUrl}/rest/v1/${table}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      Prefer: "return=representation",
    },
    body: JSON.stringify(body),
  });
}

async function supabaseUpdate(supabaseUrl: string, serviceKey: string, table: string, id: string | number, patch: Record<string, unknown>): Promise<void> {
  await fetch(`${supabaseUrl}/rest/v1/${table}?id=eq.${id}`, {
    method: "PATCH",
    headers: {
      "Content-Type": "application/json",
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
    },
    body: JSON.stringify(patch),
  });
}

serve(async (req) => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const cronSecret = Deno.env.get("CRON_SECRET") ?? "";

  const auth = req.headers.get("authorization");
  if (cronSecret && auth !== `Bearer ${cronSecret}`) {
    return new Response("Unauthorized", { status: 401 });
  }

  console.log("[Grace Reminder] Starting pass...");

  try {
    const now = new Date();
    const todayStr = now.toISOString().slice(0, 10);

    const loanRes = await fetch(
      `${supabaseUrl}/rest/v1/loans?select=id,amount,monthly_payment,first_payment_date,grace_period_months,status,vendor_id,vendors!inner(id,name,phone,email,whatsapp)&grace_period_enabled=eq.true&first_payment_date=lte.${todayStr}&status=eq.Active`,
      {
        headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}` },
      },
    );
    if (!loanRes.ok) {
      throw new Error(`Failed to fetch grace-period loans: ${loanRes.status}`);
    }
    const loans: GraceLoanRow[] = await loanRes.json();
    console.log(`[Grace Reminder] Found ${loans.length} grace-ended loans.`);

    const monthNames = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    let processed = 0;
    let sent = 0;

    for (const loan of loans) {
      const loanId = loan.id;
      const loanRef = `L-${loanId.substring(0, 8).toUpperCase()}`;

      // Skip if already logged
      const logCheck = await fetch(
        `${supabaseUrl}/rest/v1/reminder_log?loan_ref=eq.${loanRef}&reminder_type=eq.grace_period_end&select=id&limit=1`,
        { headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}` } },
      );
      if (logCheck.ok) {
        const existing = await logCheck.json();
        if (existing.length > 0) {
          console.log(`[Grace Reminder] Skipping ${loanRef} (already notified).`);
          continue;
        }
      }

      const vendor = loan.vendors;
      if (!vendor) continue;

      const dueDate = new Date(loan.first_payment_date);
      const dueStr = `${dueDate.getDate()} ${monthNames[dueDate.getMonth() + 1]} ${dueDate.getFullYear()}`;
      const amountStr = (loan.monthly_payment ?? 0).toFixed(2);
      const graceMonths = loan.grace_period_months ?? 0;
      const message = graceWhatsAppText(vendor.name, amountStr, loanRef, dueStr, graceMonths);
      const smsMessage = graceSmsText(amountStr, loanRef, dueStr);

      let whatsappSent = false;
      let smsSent = false;
      let emailSent = false;

      // WhatsApp
      const whatsappTarget = vendor.whatsapp || vendor.phone;
      if (whatsappTarget) {
        const wesenderKey = await getApiKey(supabaseUrl, serviceKey, "wesender");
        if (wesenderKey) {
          const waRes = await fetch("https://www.wasenderapi.com/api/send-message", {
            method: "POST",
            headers: { Authorization: `Bearer ${wesenderKey}`, "Content-Type": "application/json" },
            body: JSON.stringify({ to: formatPhone(whatsappTarget), text: message }),
          });
          if (waRes.ok) whatsappSent = true;
        }
      }

      // SMS
      if (vendor.phone) {
        const smsworxKey = await getApiKey(supabaseUrl, serviceKey, "smsworx");
        if (smsworxKey) {
          const parts = smsworxKey.split(":");
          if (parts.length === 2) {
            const basicAuth = btoa(`${parts[0]}:${parts[1]}`);
            const smsRes = await fetch("https://rest.mymobileapi.com/v3/BulkMessages", {
              method: "POST",
              headers: { Authorization: `Basic ${basicAuth}`, "Content-Type": "application/json" },
              body: JSON.stringify({
                sendOptions: { allowContentTrimming: true, senderId: "NSBSA" },
                messages: [{ content: smsMessage, destination: formatPhone(vendor.phone) }],
              }),
            });
            if (smsRes.ok) smsSent = true;
          }
        }
      }

      // Email
      if (vendor.email) {
        const emailHtml = buildGraceEmailHtml(vendor.name, loanRef, amountStr, dueStr, graceMonths);
        const subject = "Grace Period Ended — Loan Repayment Starts Now";
        await supabaseInsert(supabaseUrl, serviceKey, "communication_logs", {
          vendor_id: vendor.id,
          channel: "Email",
          recipient: vendor.email,
          subject,
          content: "Grace period end notice (View email for details)",
          status: "pending",
          metadata: { reminder_type: "grace_period_end", loan_ref: loanRef, monthly_payment: loan.monthly_payment, due_date: loan.first_payment_date },
        });
        await supabaseInsert(supabaseUrl, serviceKey, "email_outbox", {
          to_email: vendor.email,
          subject,
          html_content: emailHtml,
          metadata: { reminder_type: "grace_period_end", vendor_id: vendor.id, loan_ref: loanRef },
        });
        emailSent = true;
      }

      const delivered = whatsappSent || smsSent || emailSent;

      // Log to reminder_log
      await supabaseInsert(supabaseUrl, serviceKey, "reminder_log", {
        vendor_id: vendor.id,
        vendor_name: vendor.name,
        vendor_phone: vendor.phone ?? "",
        vendor_email: vendor.email ?? "",
        vendor_whatsapp: vendor.whatsapp ?? "",
        loan_amount: loan.amount,
        balance: loan.monthly_payment ?? 0,
        loan_ref: loanRef,
        due_date: loan.first_payment_date,
        reminder_type: "grace_period_end",
        sent: delivered,
        error: delivered ? null : "All channels failed",
        created_at: now.toISOString(),
      });

      if (delivered) sent++;
      processed++;
    }

    console.log(`[Grace Reminder] Done. Processed ${processed}, sent ${sent}.`);
    return new Response(JSON.stringify({ ok: true, processed, sent }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error("[Grace Reminder] Error:", e);
    return new Response(JSON.stringify({ ok: false, error: e.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
