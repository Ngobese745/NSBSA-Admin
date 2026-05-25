// Supabase Edge Function — Payment Reminder Scheduler
//
// Deploy: supabase functions deploy process-payment-reminders --no-verify-jwt
// Schedule (08:00 & 18:00 daily):
//   supabase secrets set SCHEDULE_CRON_REMINDERS="0 8,18 * * *"
//
// This function queries active loans with upcoming/overdue instalments and
// dispatches reminders via email_outbox (MailerSend), WhatsApp (WeSenderAPI),
// and SMS (SMSWORX).  Each communication is logged in the communication_logs
// table for auditability.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

interface VendorInfo {
  id: string;
  name: string;
  phone: string | null;
  email: string | null;
  whatsapp_number: string | null;
}

interface LoanRow {
  id: string;
  amount: number;
  first_instalment_date: string;
  status: string;
  group_id: string;
  vendor_id: string;
  vendors: VendorInfo;
}

interface ReminderInvoice {
  vendorId: string;
  vendorName: string;
  phone: string;
  email: string;
  whatsapp: string;
  loanRef: string;
  balance: number;
  dueDate: string;
}

// ---------------------------------------------------------------------------
// MailerSend — HTML email (dark NSBSA theme + gold accents)
// ---------------------------------------------------------------------------
function buildEmailHtml(
  name: string,
  ref: string,
  amount: string,
  due: string,
  isFollowUp: boolean,
): string {
  const urgencyBanner = isFollowUp
    ? `<div style="background:#FF7B72;color:#fff;text-align:center;padding:12px;font-weight:700;font-size:14px;">
        ⚠️ FINAL REMINDER — Pay immediately to avoid penalties.</div>`
    : "";
  const body = isFollowUp
    ? "This is a final reminder that your loan payment is overdue."
    : "This is a friendly reminder of your upcoming loan payment.";

  const subject = isFollowUp
    ? "Final Reminder — Loan Payment Due"
    : "Payment Reminder — NSBSA Loan";

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
</style></head><body>
<div class="container">
<div class="header"><div class="tagline">NSBSA | Empowering Communities</div></div>
${urgencyBanner}
<div class="content">
<p>Dear <strong>${name}</strong>,</p>
<p>${body}</p>
<table class="tbl">
<tr><th>Loan Reference</th><td>${ref}</td></tr>
<tr><th>Amount Due</th><td>R${amount}</td></tr>
<tr><th>Due Date</th><td>${due}</td></tr>
</table>
<p>Please arrange payment at your nearest NSBSA branch or via your group representative.</p>
<p style="font-size:12px;color:#8B949E;">Penalty applies if payment is missed by 20+ days.</p>
</div>
<div class="footer">
<p><strong>Contact NSBSA</strong><br>Email: info@nsbsa.org.za | Phone: 087 107 7524</p>
<p style="font-size:10px;">Automated communication from NSBSA.</p>
</div></div></body></html>`;
}

// ---------------------------------------------------------------------------
// WhatsApp / SMS templates
// ---------------------------------------------------------------------------
function whatsAppText(
  name: string,
  amount: string,
  ref: string,
  due: string,
  isFollowUp: boolean,
): string {
  return isFollowUp
    ? `Final reminder: Your loan payment of R${amount} is overdue. Ref: ${ref}. Pay immediately to avoid penalties.`
    : `Dear ${name}, your loan payment of R${amount} is due on ${due}. Ref: ${ref}. Please settle to avoid penalties.`;
}

function smsText(amount: string, ref: string, due: string, isFollowUp: boolean): string {
  return isFollowUp
    ? `NSBSA: Final reminder. Loan payment R${amount} overdue. Ref: ${ref}. Pay immediately to avoid penalties.`
    : `NSBSA: Loan payment R${amount} due ${due}. Ref: ${ref}. Pay now to avoid penalties.`;
}

// ---------------------------------------------------------------------------
// API key helpers
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// Supabase RPC call helpers
// ---------------------------------------------------------------------------
async function supabaseRpc(
  supabaseUrl: string,
  serviceKey: string,
  table: string,
  body: unknown,
): Promise<Response> {
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

async function supabaseUpdate(
  supabaseUrl: string,
  serviceKey: string,
  table: string,
  id: string | number,
  patch: Record<string, unknown>,
): Promise<void> {
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

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------
serve(async (req) => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const cronSecret = Deno.env.get("CRON_SECRET") ?? "";

  // Optional: verify bearer token from cron trigger
  const auth = req.headers.get("authorization");
  if (cronSecret && auth !== `Bearer ${cronSecret}`) {
    return new Response("Unauthorized", { status: 401 });
  }

  // Determine pass type from query string: ?type=initial (default) or ?type=follow_up
  const url = new URL(req.url);
  const reminderType = url.searchParams.get("type") ?? "initial";
  const isFollowUp = reminderType === "follow_up";

  console.log(`[Reminder ${reminderType}] Starting pass...`);

  try {
    // 1. Fetch active loans with vendor info
    const loanRes = await fetch(
      `${supabaseUrl}/rest/v1/loans?select=id,amount,first_instalment_date,status,group_id,vendor_id,vendors!inner(id,name,phone,email,whatsapp_number)&status=eq.Active`,
      {
        headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}` },
      },
    );
    if (!loanRes.ok) {
      throw new Error(`Failed to fetch loans: ${loanRes.status}`);
    }
    const loans: LoanRow[] = await loanRes.json();

    const now = new Date();
    const todayStr = now.toISOString().slice(0, 10);

    // 2. Filter: only loans with first_instalment_date <= today
    const dueInvoices: ReminderInvoice[] = [];

    for (const loan of loans) {
      if (!loan.first_instalment_date) continue;
      const due = new Date(loan.first_instalment_date);
      if (due > now) continue;

      const vendor = loan.vendors;
      if (!vendor) continue;

      // Calculate balance
      const payRes = await fetch(
        `${supabaseUrl}/rest/v1/payments?select=amount_paid&loan_id=eq.${loan.id}`,
        { headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}` } },
      );
      const payments: { amount_paid: number }[] = await payRes.json();
      const totalPaid = payments.reduce((s, p) => s + p.amount_paid, 0);
      const balance = loan.amount - totalPaid;
      if (balance <= 0) continue;

      dueInvoices.push({
        vendorId: vendor.id,
        vendorName: vendor.name,
        phone: vendor.phone ?? "",
        email: vendor.email ?? "",
        whatsapp: vendor.whatsapp_number ?? "",
        loanRef: loan.id.slice(0, 8).toUpperCase(),
        balance,
        dueDate: loan.first_instalment_date,
      });
    }

    console.log(`[Reminder] ${dueInvoices.length} vendors due.`);

    // 3. Send per channel
    const monthNames = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

    for (const inv of dueInvoices) {
      const dueDate = new Date(inv.dueDate);
      const dueStr = `${dueDate.getDate()} ${monthNames[dueDate.getMonth() + 1]} ${dueDate.getFullYear()}`;
      const amountStr = inv.balance.toFixed(2);
      const amountStrShort = inv.balance.toFixed(0);

      // 3a. Email — queue to email_outbox
      if (inv.email) {
        const subject = isFollowUp ? "Final Reminder — Loan Payment Due" : "Payment Reminder — NSBSA Loan";
        const emailHtml = buildEmailHtml(inv.vendorName, inv.loanRef, amountStr, dueStr, isFollowUp);

        const logRes = await supabaseRpc(supabaseUrl, serviceKey, "communication_logs", {
          vendor_id: inv.vendorId,
          channel: "Email",
          recipient: inv.email,
          subject,
          content: "Reminder sent (View email for details)",
          status: "pending",
          metadata: { reminder_type: reminderType, loan_ref: inv.loanRef, balance: inv.balance, due_date: inv.dueDate },
        });
        const log = await logRes.json();
        const logId = log?.[0]?.id;

        await supabaseRpc(supabaseUrl, serviceKey, "email_outbox", {
          to_email: inv.email,
          subject,
          html_content: emailHtml,
          log_id: logId,
          metadata: { reminder_type: reminderType, vendor_id: inv.vendorId, loan_ref: inv.loanRef },
        });
      }

      // 3b. WhatsApp — via WeSenderAPI
      const whatsappTarget = inv.whatsapp || inv.phone;
      if (whatsappTarget) {
        const wesenderKey = await getApiKey(supabaseUrl, serviceKey, "wesender");
        if (wesenderKey) {
          const waMsg = whatsAppText(inv.vendorName, amountStr, inv.loanRef, dueStr, isFollowUp);
          const logRes = await supabaseRpc(supabaseUrl, serviceKey, "communication_logs", {
            vendor_id: inv.vendorId,
            channel: "WhatsApp",
            recipient: whatsappTarget,
            content: waMsg,
            status: "pending",
            metadata: { reminder_type: reminderType, loan_ref: inv.loanRef, balance: inv.balance, due_date: inv.dueDate },
          });
          const log = await logRes.json();
          const logId = log?.[0]?.id;

          const waRes = await fetch("https://www.wasenderapi.com/api/send-message", {
            method: "POST",
            headers: {
              Authorization: `Bearer ${wesenderKey}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({ to: formatPhone(whatsappTarget), text: waMsg }),
          });

          const waOk = waRes.ok;
          if (logId) {
            await supabaseUpdate(supabaseUrl, serviceKey, "communication_logs", logId, {
              status: waOk ? "sent" : "failed",
              ...(waOk ? {} : { error_message: "WhatsApp delivery failed" }),
            });
          }
        }
      }

      // 3c. SMS — via SMSWORX
      if (inv.phone) {
        const smsworxKey = await getApiKey(supabaseUrl, serviceKey, "smsworx");
        if (smsworxKey) {
          const smsMsg = smsText(amountStrShort, inv.loanRef, dueStr, isFollowUp);
          const logRes = await supabaseRpc(supabaseUrl, serviceKey, "communication_logs", {
            vendor_id: inv.vendorId,
            channel: "SMS",
            recipient: inv.phone,
            content: smsMsg,
            status: "pending",
            metadata: { reminder_type: reminderType, loan_ref: inv.loanRef, balance: inv.balance, due_date: inv.dueDate },
          });
          const log = await logRes.json();
          const logId = log?.[0]?.id;

          const parts = smsworxKey.split(":");
          if (parts.length === 2) {
            const basicAuth = btoa(`${parts[0]}:${parts[1]}`);
            const smsRes = await fetch("https://rest.mymobileapi.com/v3/BulkMessages", {
              method: "POST",
              headers: {
                Authorization: `Basic ${basicAuth}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                sendOptions: { allowContentTrimming: true, senderId: "NSBSA" },
                messages: [{ content: smsMsg, destination: formatPhone(inv.phone) }],
              }),
            });

            if (logId) {
              await supabaseUpdate(supabaseUrl, serviceKey, "communication_logs", logId, {
                status: smsRes.ok ? "sent" : "failed",
                ...(smsRes.ok ? {} : { error_message: "SMS delivery failed" }),
              });
            }
          }
        }
      }
    }

    return new Response(
      JSON.stringify({ ok: true, type: reminderType, processed: dueInvoices.length }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (e) {
    console.error("[Reminder] Error:", e);
    return new Response(JSON.stringify({ ok: false, error: e.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
