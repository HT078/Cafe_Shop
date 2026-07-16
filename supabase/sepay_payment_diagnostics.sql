-- ============================================================
-- KIEM TRA THANH TOAN SEPAY - CA PHE HAI TIN
-- Chi doc du lieu, khong thay doi trang thai don hang.
-- ============================================================

-- 1. Kiem tra cac don VietQR moi nhat.
select
  order_code,
  total,
  payment_status,
  status,
  payment_method,
  sepay_transaction_id,
  payment_reference,
  payment_confirmed_at,
  created_at
from public.orders
where lower(coalesce(payment_method, '')) = 'vietqr'
order by created_at desc
limit 20;

-- 2. Kiem tra webhook Live da den Supabase hay chua.
select
  transaction_id,
  order_code,
  amount,
  transfer_type,
  status,
  error_message,
  received_at,
  processed_at
from public.sepay_transactions
order by received_at desc
limit 20;

-- Cach doc ket qua:
-- Khong co dong moi: webhook Live chua duoc tao/bat hoac chua goi lai giao dich.
-- order_not_found: noi dung chuyen khoan khong khop ma don.
-- amount_mismatch: so tien chuyen khong khop tong don.
-- paid: Supabase da xac nhan thanh toan thanh cong.
