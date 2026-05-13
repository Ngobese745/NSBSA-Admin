-- SQL Diagnostic: Find any hardcoded email in triggers or functions
-- Run this in your Supabase SQL Editor to find where the hardcoding is.

SELECT 
    proname as function_name, 
    prosrc as function_source
FROM 
    pg_proc 
WHERE 
    prosrc ILIKE '%colane.comfort.5@gmail.com%';
