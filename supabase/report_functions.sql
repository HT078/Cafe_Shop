-- Revenue report helpers for Supabase SQL Editor.
-- The Flutter screen also has a direct table-query fallback, so these
-- functions are optional but useful if you want RPC-based reporting later.

CREATE OR REPLACE FUNCTION public.get_revenue_by_day(from_date DATE, to_date DATE)
RETURNS TABLE (day DATE, revenue BIGINT, order_count INT) AS $$
BEGIN
  RETURN QUERY
  SELECT
    DATE(created_at) AS day,
    COALESCE(SUM(total), 0)::BIGINT AS revenue,
    COUNT(*)::INT AS order_count
  FROM public.orders
  WHERE
    status IN ('Đã giao', 'Hoàn tất', 'delivered', 'completed')
    AND DATE(created_at) >= from_date
    AND DATE(created_at) <= to_date
  GROUP BY DATE(created_at)
  ORDER BY day;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.get_top_products(
  from_date DATE,
  to_date DATE,
  limit_count INT DEFAULT 10
)
RETURNS TABLE (
  product_name TEXT,
  total_quantity BIGINT,
  total_revenue BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    oi.product_name,
    SUM(oi.quantity)::BIGINT AS total_quantity,
    SUM(COALESCE(oi.line_total, oi.subtotal, 0))::BIGINT AS total_revenue
  FROM public.order_items oi
  JOIN public.orders o ON o.id = oi.order_id
  WHERE
    o.status IN ('Đã giao', 'Hoàn tất', 'delivered', 'completed')
    AND DATE(o.created_at) >= from_date
    AND DATE(o.created_at) <= to_date
  GROUP BY oi.product_name
  ORDER BY total_quantity DESC, total_revenue DESC
  LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.get_report_summary(from_date DATE, to_date DATE)
RETURNS TABLE (
  total_orders BIGINT,
  delivered_orders BIGINT,
  cancelled_orders BIGINT,
  pending_orders BIGINT,
  total_revenue BIGINT,
  wholesale_revenue BIGINT,
  retail_revenue BIGINT,
  avg_order_value BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*)::BIGINT AS total_orders,
    COUNT(*) FILTER (
      WHERE status IN ('Đã giao', 'Hoàn tất', 'delivered', 'completed')
    )::BIGINT AS delivered_orders,
    COUNT(*) FILTER (
      WHERE LOWER(status) LIKE '%hủy%' OR LOWER(status) LIKE '%huy%' OR LOWER(status) LIKE '%cancel%'
    )::BIGINT AS cancelled_orders,
    COUNT(*) FILTER (
      WHERE status NOT IN ('Đã giao', 'Hoàn tất', 'delivered', 'completed')
        AND LOWER(status) NOT LIKE '%hủy%'
        AND LOWER(status) NOT LIKE '%huy%'
        AND LOWER(status) NOT LIKE '%cancel%'
    )::BIGINT AS pending_orders,
    COALESCE(SUM(total) FILTER (
      WHERE status IN ('Đã giao', 'Hoàn tất', 'delivered', 'completed')
    ), 0)::BIGINT AS total_revenue,
    COALESCE(SUM(total) FILTER (
      WHERE status IN ('Đã giao', 'Hoàn tất', 'delivered', 'completed')
        AND is_wholesale = TRUE
    ), 0)::BIGINT AS wholesale_revenue,
    COALESCE(SUM(total) FILTER (
      WHERE status IN ('Đã giao', 'Hoàn tất', 'delivered', 'completed')
        AND COALESCE(is_wholesale, FALSE) = FALSE
    ), 0)::BIGINT AS retail_revenue,
    COALESCE(AVG(total) FILTER (
      WHERE status IN ('Đã giao', 'Hoàn tất', 'delivered', 'completed')
    ), 0)::BIGINT AS avg_order_value
  FROM public.orders
  WHERE DATE(created_at) >= from_date AND DATE(created_at) <= to_date;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
