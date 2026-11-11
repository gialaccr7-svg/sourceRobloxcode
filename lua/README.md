# Goku Battleground

Mở `game.rbxlx` bằng **File → Open from File** trong Roblox Studio. Đây là bản place đầy đủ, đã build bằng Rojo 7.7.1.

Để chỉnh sửa và build lại, giữ `src/`, `assets/` và `default.project.json`. Với [Rojo CLI](https://github.com/rojo-rbx/rojo/releases) đã cài, chạy từ thư mục dự án:

```powershell
rojo build default.project.json -o game.rbxlx
```

- Animation R15 tự dựng, không cần upload Animation ID: combo M1, barrage, Kamehameha, Kaioken slam, Instant Transmission, Spirit Bomb và biến hình.
- Map 480×480 studs, giữ võ đài trung tâm; thêm sân tập, sân phụ, vườn cây, đường dạo và khán đài.
- Điều khiển: chuột trái đánh; Z/X/C/V dùng chiêu tương ứng ô 1/2/3/4; F đỡ; Q dash; G biến hình khi đủ rage.

Đã sửa lỗi khởi tạo remote khiến phím skill không hoạt động. Phím Z/X/C/V gửi lệnh ngay khi nhấn, không còn chặn nhập 0,25 giây; có thể dùng khi đang đánh thường và tự bỏ đỡ. Hồi chiêu, choáng, ragdoll và trạng thái phản đòn vẫn được kiểm tra.

Kiểm tra hồi quy phần skill bằng Luau CLI: `node tests/skill-input.cjs đường-dẫn-tới-luau.exe`. Bài kiểm tra chạy code thật với dịch vụ Roblox giả lập: khởi tạo remote, cả bốn skill, đánh thường/đỡ, hồi chiêu, khóa trạng thái, lỗi hiệu ứng, hồi sinh, nhập trùng UIS/CAS, bấm nhanh và nhập chat.

Phần nhận phím được kết nối độc lập với việc tải module combat/hiệu ứng; khi module chưa sẵn sàng, lệnh skill vẫn được gửi tới server. Skill server cũng khởi tạo độc lập với phần thiết lập nhân vật và M1. Đã kiểm tra thêm module tải bị treo và nhả/nhấn lại cùng InputObject.

Sau khi thay file, hãy Stop phiên chạy cũ, mở lại `game.rbxlx` từ ổ đĩa và chọn Play (F5), rồi click vào khung game trước khi bấm Z/X/C/V. Output của bản này có `[CombatController] Z/X/C/V input ready (skill-input-fix-2).` ở client và `[SkillInit] Z/X/C/V skill server ready.` ở server. Những kiểm tra mô phỏng không thay thế việc chạy Play trong Studio.

Đã kiểm tra: biên dịch toàn bộ 25 script trong file place; 52 lượt mô phỏng animation ở nhiều FPS; hủy chiêu, ragdoll, looping block, phát animation cho người quan sát; liên kết rig, map và spawn.

Chưa chạy Play trực tiếp trong Roblox Studio. Bản xem trước tư thế được kiểm tra từ ma trận khớp; cần Play trong Studio để đánh giá cảm giác chiến đấu và vật lý thực tế.
