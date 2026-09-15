# Nhận diện và làm đẹp tự nhiên — 12/09/2026

## Kết luận công nghệ

TikTok công khai **Lip Segmentation** để tách môi khỏi ảnh, và **Face Retouch** để làm mịn kết cấu da, giữ đường nét, chỉnh riêng quầng mắt và nếp cười. Đây là bằng chứng về tính năng công khai, không phải mã nguồn hay mô hình nội bộ của toàn bộ ứng dụng. Chính tài liệu TikTok cũng nêu phân vùng môi có chi phí xử lý cao trên iOS: không có căn cứ để hứa “0 ms”.

Nguồn: [TikTok Lip Segmentation](https://effecthouse.us.tiktok.com/learn/guides/workspace/objects/segmentation/lip-segmentation), [TikTok Face Retouch](https://effecthouse.tiktok.com/learn/guides/workspace/objects/face-effects/face-retouch).

Volcengine xác nhận SDK làm đẹp của họ được sử dụng trong **Douyin, Huoshan, Qingyan và Faceu**. Không nên tự động diễn giải Douyin thành tất cả phiên bản TikTok, hoặc suy ra mọi tính năng Xingtu đều dùng cùng mô hình. BytePlus công bố Portrait SDK nhận tới **280 điểm**, kèm nhận dạng chuyển động mắt, miệng. Nhiều điểm hơn không tự nó bảo đảm chất lượng cao hơn: độ chính xác vùng môi, phân vùng và sự đồng bộ với ảnh mới quyết định kết quả.

Nguồn: [Volcengine SDK overview](https://www.volcengine.com/docs/6705/1160378?lang=zh), [BytePlus Portrait](https://docs.byteplus.com/en/docs/effects/docs-portrait).

**Xingtu (醒图)** công bố sử dụng thuật toán hiệu ứng Jianying, gồm hiểu nội dung, dựng ảnh trên thiết bị và một số hiệu ứng dùng học sâu. Tài liệu này không tiết lộ cấu trúc mạng riêng cho viền môi, trọng số mô hình, hoặc thuật toán làm mịn cụ thể. Bài kỹ thuật của đội ByteDance xác nhận Xingtu tham gia nền tảng kiểm thử hiệu ứng chung, gồm phân loại thiết bị theo hiệu năng; điều đó không chứng minh toàn bộ engine giống TikTok.

Nguồn: [Công bố thuật toán Xingtu](https://lf9-cdn-tos.draftstatic.com/obj/ies-hotsoon-draft/vco/6b9ed528-0140-4334-85a7-22105811e056.html), [ByteDance CQ](https://developer.volcengine.com/articles/7599493516238979082).

## Các lỗi cụ thể trong repo và thay đổi

Phạm vi thực thi hiện tại là **macOS**, nơi repo triển khai camera và bộ xử lý ảnh thực tế.

| Vấn đề trong mã cũ | Thay đổi |
| --- | --- |
| Render ảnh mới với landmarks trả về từ tác vụ bất đồng bộ của ảnh cũ | Nhận diện và render cùng một buffer, trên luồng camera; AVCapture bỏ khung đến muộn, không tích hàng đợi |
| Giữ landmarks cũ qua hơn 8 lần mất mặt | Xóa kết quả ngay khi mất mặt/lỗi suy luận; reset bộ lọc khi đổi camera, kích thước hoặc ngắt timestamp |
| Bộ lọc lấy đạo hàm từ vị trí đã làm mượt | Dùng chênh lệch giữa hai mẫu thô, tránh phản hồi sai vận tốc |
| Chỉnh hình trước, nhưng mask da/trang điểm vẫn ở tọa độ cũ | Làm da và trang điểm trước, sau đó biến dạng cả ảnh cùng nhau |
| Mask da blur 14 px, có fallback hình oval phủ mắt/miệng | Feather nhỏ theo kích thước mặt và giới hạn trong mask gốc; bỏ fallback oval |
| Trộn blur Gaussian rộng vào da | Lọc theo khác biệt màu, giữ chi tiết và cạnh; bán kính theo kích thước mặt |
| Mask môi làm mờ tràn ra da hoặc vào miệng | Vẽ riêng vành môi và lỗ miệng, feather vào phía trong; chỉ tạo bitmap ở vùng môi |
| Độ đậm trang điểm thay đổi alpha trong khi blend dùng độ sáng mask | Thay đổi RGB của mask đúng với CIBlendWithMask |
| Làm trắng răng trên oval quanh miệng | Giới hạn vào contour trong miệng và pixel sáng, ít bão hòa màu |
| Chỉ hiện thời gian render dưới tên GPU latency | Hiện thời gian tracking và tổng tracking + render; đếm khung camera bị bỏ |

Cách lọc màu và mesh ở đây **chưa phải mô hình phân vùng da/môi theo từng pixel**. Tay che miệng, râu, môi nhợt, góc nghiêng lớn và thiếu sáng vẫn cần kiểm thử và có thể cần model chuyên biệt. Việc xóa mặt khi mất nhận diện không thay thế xử lý che khuất nếu model vẫn báo có mặt.

## Hướng đồng bộ công nghệ và tính năng

**Lựa chọn thương mại gần hệ sinh thái ByteDance:** đánh giá BytePlus Effects trên macOS với đúng máy mục tiêu. SDK có hướng dẫn macOS dùng thư viện `libeffect.dylib`; tài liệu hiện công bố tích hợp OpenGL, vì vậy không thể giả định thay trực tiếp vào pipeline Metal là xong. Cần SDK binary/header, bộ tài nguyên phù hợp và giấy phép macOS. Chưa tích hợp SDK này trong thay đổi hiện tại.

Nguồn: [BytePlus Mac Access Guide](https://docs.byteplus.com/api/docs/effects/docs-mac-access-guide), [BytePlus license](https://docs.byteplus.com/api/docs/effects/docs-about-license).

**Lựa chọn tự phát triển:** đánh giá Attention Mesh/refinement cho môi và mắt, thêm phân vùng môi/da/che khuất, rồi dựng mặt nạ chung cho mọi tính năng. Google mô tả Attention Mesh tập trung vào vùng mắt và môi cho AR makeup. Chuyển đổi và benchmark trên Core ML/macOS là công việc riêng; không thể đổi tên model 468 điểm hiện có để có chất lượng đó.

Nguồn: [Google Attention Mesh](https://research.google/pubs/attention-mesh-high-fidelity-face-mesh-prediction-in-real-time/).

| Nhóm | Đã sửa trong pipeline hiện tại | Cần đánh giá tiếp |
| --- | --- | --- |
| Tracking | Đồng bộ ảnh/điểm mặt, reset dữ liệu lỗi | Refinement môi/mắt, độ tin cậy vùng, che khuất |
| Môi | Vành môi/lỗ miệng, feather, độ đậm, đồng bộ reshape | Semantic segmentation theo pixel, giữ highlight vật liệu theo ánh sáng |
| Da | Lọc giữ cạnh/kết cấu, bảo vệ vùng đặc trưng | Phân vùng da thực, bảo vệ râu/tóc/tay, xử lý mụn chọn lọc |
| Hiệu năng | Bỏ khung muộn, đo cả tracking + render | Benchmark SDK và model trên từng thiết bị, p50/p95 |
| Đa nền tảng | Các chỉnh sửa trong engine macOS | Tích hợp tương đương iOS/Android sau khi chọn SDK |

## Cách nghiệm thu

- Dùng cùng video và cùng mức hiệu ứng: nói nhanh, cười, há miệng, nghiêng đầu, quay mặt, che môi, rời khung rồi quay lại; thử da sáng/tối, râu, kính và thiếu sáng.
- So sánh khung gốc với khung xử lý: son không phủ răng hoặc da quanh miệng; không có môi kép khi chuyển động; lỗ chân lông và bóng khối còn tự nhiên.
- Kiểm tra son riêng, reshape riêng, và cả hai đồng thời; thử opacity 0/20/50/80/100.
- Đo p50/p95 tracking và processing, FPS và dropped frames ở 720p30, 1080p30, 720p60. Ngân sách xử lý tham khảo cho 30 FPS là 33,3 ms/khung; 60 FPS là 16,7 ms/khung. Đây là mục tiêu, chưa phải kết quả đo.
- Thời gian processing trong ứng dụng chưa bao gồm toàn bộ thời gian từ cảm biến tới màn hình/ứng dụng gọi video. Muốn đo độ trễ đầu-cuối cần thêm phép đo camera/display.
- Test tự động dùng ảnh tổng hợp kiểm tra mask, opacity, bảo vệ vùng miệng và bộ lọc thời gian. Chúng không chứng minh độ chính xác model trên mặt thật hay chất lượng ngang TikTok/Xingtu.
