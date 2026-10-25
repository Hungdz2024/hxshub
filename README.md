# Universal UI, Night Vision & Crosshair Arrow ESP

Dự án Luau tối ưu hóa chuyên biệt cho **Roblox Mobile (Delta Client, Codex, Arceus X)** và PC Executors, tuân thủ kiến trúc modular 3-tier, zero memory leak và không drop FPS.

---

## 📁 Cấu trúc dự án (Modular Structure)

```text
e:/rbl_script/
├── init.lua                  # [Entry Point] Khởi tạo State toàn cục, nạp UI & Modules
├── core/
│   ├── state.lua             # Lưu trữ biến trạng thái (Flags/Settings) và Cache dữ liệu
│   └── maid.lua              # Quản lý dọn dẹp kết nối sự kiện (Connections/RAM)
├── ui/
│   └── floating_bubble.lua   # Bong bóng nổi (Drag/Tap delta > 5px) và bảng Menu chính
├── modules/
│   ├── night_vision.lua      # Snapshot và can thiệp Lighting (Fullbright)
│   └── arrow_esp.lua         # Scanner Loop (0.4s), Object Pooling (15 ImageLabels), atan2 math
└── dist/
    └── bundle.lua            # Single-file standalone ném lên GitHub raw chạy loadstring()
```

---

## ⚡ 3-Tier Execution Pipeline (Khắc phục tụt FPS Mobile)

1. **Event-Driven Tier:**
   - Bong bóng nổi phân biệt chuẩn xác giữa **Tap** (chạm nhẹ mở menu) và **Drag** (giữ kéo thả) nhờ kiểm tra `delta.Magnitude > 5px`.
   - Bật/tắt Toggle cập nhật trực tiếp vào `State.Flags`.

2. **Scanner Loop Tier (Chạy ngầm mỗi 0.4s):**
   - Quét Workspace tìm Player và Mob/NPC còn sống (`Humanoid.Health > 0`).
   - Lọc trong bán kính `MaxDistance = 500 studs`.
   - Sắp xếp tăng dần theo khoảng cách và lưu tối đa 15 mục tiêu gần nhất vào `State.TargetCache`.
   - **Tuyệt đối không quét Workspace trong RenderStepped**, tiết kiệm tài nguyên CPU của điện thoại.

3. **Render Loop Tier (RenderStepped mỗi frame):**
   - Chỉ đọc từ mảng `TargetCache` có sẵn.
   - Sử dụng **Object Pooling** với 15 `ImageLabel` tạo sẵn từ đầu. Không bao giờ gọi `Instance.new` hay `:Destroy()` trong vòng lặp frame.
   - Chuyển tọa độ thế giới sang Camera Object Space: `relativePos = Camera.CFrame:PointToObjectSpace(targetPos)`.
   - Tính góc phương vị la bàn qua hàm `math.atan2(relativePos.Z, relativePos.X)`.
   - Định vị mũi tên trên đường tròn bán kính 90px quanh tâm ngắm (`math.cos`, `math.sin`).
   - Distance Lerp: Màu đỏ (mục tiêu ở sát mặt) chuyển dần sang xanh lá (mục tiêu ở xa).

---

## 🚀 Cách chạy trên Delta Client Mobile

### Cách 1: Đẩy file `dist/bundle.lua` lên GitHub Repo của bạn
1. Tạo một repository trên GitHub (ví dụ: `rbl-hub`).
2. Copy toàn bộ code trong [`dist/bundle.lua`](file:///e:/rbl_script/dist/bundle.lua) vào file `main.lua` trên repo.
3. Lấy link Raw GitHub và dán vào Delta Executor trên điện thoại:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/<user>/<repo>/main/main.lua"))()
```

### Cách 2: Test trực tiếp file bundle trong Delta
Mở Delta Mobile, mở tab Code Editor, dán thẳng nội dung của [`dist/bundle.lua`](file:///e:/rbl_script/dist/bundle.lua) và nhấn **Execute**.
