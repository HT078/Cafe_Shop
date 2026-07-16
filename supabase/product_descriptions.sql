-- Product description updates for the customer product detail screen.
-- Run this manually in the Supabase SQL Editor after confirming product IDs.

BEGIN;

UPDATE public.products
SET description = $desc$
Hạt Robusta chọn lọc từ Đắk Lắk, rang mộc truyền thống. Vị đắng mạnh, hậu vị ngọt thanh, mùi thơm khói đặc trưng.

1. THÔNG TIN CHUNG:
- Định lượng: 250g / 500g / 1kg
- Thành phần: 100% Robusta Đắk Lắk
- Hạn sử dụng: 12 tháng kể từ ngày rang
- Xuất xứ: Việt Nam
- Thương hiệu: Cà Phê Hải Tín

2. HƯỚNG DẪN PHA CHẾ:
- Tỉ lệ: 20-25g cà phê / 200ml nước
- Nhiệt độ nước: 90-95°C
- Thời gian pha phin: 4-5 phút
- Có thể pha thêm đá, sữa đặc tùy khẩu vị

3. BẢO QUẢN:
- Bảo quản nơi khô ráo, thoáng mát
- Tránh ánh nắng trực tiếp và độ ẩm cao
- Sau khi mở: nên dùng trong vòng 30 ngày
$desc$
WHERE id = 'prod-001';

UPDATE public.products
SET description = $desc$
Arabica trồng tại Cầu Đất - Đà Lạt, độ cao 1.500m. Vị chua thanh nhẹ, hương hoa quả đặc trưng.

1. THÔNG TIN CHUNG:
- Định lượng: 250g / 500g / 1kg
- Thành phần: 100% Arabica Cầu Đất
- Hạn sử dụng: 12 tháng kể từ ngày rang
- Xuất xứ: Đà Lạt, Việt Nam
- Thương hiệu: Cà Phê Hải Tín

2. HƯỚNG DẪN PHA CHẾ:
- Phù hợp: pour-over, cold brew, drip
- Tỉ lệ: 15g cà phê / 250ml nước
- Nhiệt độ nước: 88-92°C
- Có thể dùng đá lớn để pha lạnh giữ vị thanh

3. BẢO QUẢN:
- Bảo quản nơi khô ráo, thoáng mát
- Tránh ánh nắng trực tiếp và độ ẩm cao
- Sau khi mở: nên dùng trong vòng 14 ngày
$desc$
WHERE id = 'prod-002';

UPDATE public.products
SET description = $desc$
Hạt Culi (Peaberry) đặc biệt từ Buôn Mê Thuột. Hàm lượng caffeine cao hơn hạt thường, vị đậm và hậu vị kéo dài.

1. THÔNG TIN CHUNG:
- Định lượng: 250g / 500g / 1kg
- Thành phần: 100% Robusta Culi
- Hạn sử dụng: 12 tháng kể từ ngày rang
- Xuất xứ: Buôn Mê Thuột, Đắk Lắk
- Thương hiệu: Cà Phê Hải Tín

2. HƯỚNG DẪN PHA CHẾ:
- Tỉ lệ: 20-25g cà phê / 200ml nước
- Nhiệt độ nước: 90-95°C
- Thời gian pha phin: 5-6 phút
- Phù hợp người thích gu cà phê mạnh

3. BẢO QUẢN:
- Bảo quản nơi khô ráo, thoáng mát
- Tránh ánh nắng trực tiếp và độ ẩm cao
- Sau khi mở: nên dùng trong vòng 30 ngày
$desc$
WHERE id = 'prod-003';

UPDATE public.products
SET description = $desc$
Công thức pha trộn 70% Robusta + 30% Arabica, thêm bơ rang tạo vị béo ngậy, đậm chất cà phê phin Việt Nam.

1. THÔNG TIN CHUNG:
- Định lượng: 250g / 500g / 1kg
- Thành phần: 70% Robusta + 30% Arabica + bơ
- Hạn sử dụng: 6 tháng kể từ ngày rang
- Xuất xứ: Việt Nam
- Thương hiệu: Cà Phê Hải Tín

2. HƯỚNG DẪN PHA CHẾ:
- Tỉ lệ: 25g cà phê / 200ml nước
- Nhiệt độ nước: 92-95°C
- Thời gian pha phin: 4-5 phút
- Ngon nhất khi pha phin với sữa đặc

3. BẢO QUẢN:
- Bảo quản nơi khô ráo, thoáng mát
- Tránh ánh nắng trực tiếp và độ ẩm cao
- Sau khi mở: nên dùng trong vòng 20 ngày
$desc$
WHERE id = 'prod-004';

COMMIT;
