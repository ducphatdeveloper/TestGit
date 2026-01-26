-- ================================================================================================================================
-- DATABASE: SmartMoney
-- AUTHOR DATABASE: Phạm Đức Phát 
-- CREATED: 2026 
-- VERSION: 1.0 (Standardized)
-- DESCRIPTION: Quản lý tài chính cá nhân với AI Assistant - Thu/Chi/Ngân sách/Sổ Nợ/Tiết kiệm/Hóa Đơn/Giao dịch định kỳ/Sự kiện
-- =================================================================================================================================
-- =======================================================================================================
-- DỰ ÁN: SMARTMONEY - QUY TẮC PHÁT TRIỂN & TỪ ĐIỂN KỸ THUẬT
-- VERSION: 1.0 | TEAM: Phát - Nhật - Nam | THỜI GIAN: 4 Tuần
-- =======================================================================================================
-- 📌 LƯU Ý: Đây là guideline tham khảo để nhóm dễ research, không bắt buộc áp dụng 100%

-- 1. QUY CHUẨN KIỂU DỮ LIỆU
--    Tiền tệ: DECIMAL(18,2)    | Ngày: DATE       | Time: DATETIME
--    Status: BIT/TINYINT        | ID: INT IDENTITY | Password: VARCHAR(255) (Bcrypt)

-- 2. QUY TẮC ĐẶT TÊN
--    Table: tTableName     | View: vViewName     | Index: idx_Table_Columns
--    Trigger: trg_Table_Action | FK: FK_Child_Parent | Constraint: CHK_Table_Field

-- 3. BẢO MẬT & QUYỀN TRUY CẬP (BẮT BUỘC)
--    □ Mọi query phải có WHERE acc_id = ? (Row-level security)
--    □ Hash password: Bcrypt cost 12 | JWT: 15 phút + Refresh 7 ngày
--    □ Admin: Chỉ Lock/Unlock account, không xóa Account/Role/Currency

-- 4. QUAN HỆ DATABASE
--    ┌────────────┬─────────────────┬───────────────────────────────────┐
--    │ LOẠI       │ VÍ DỤ           │ CÁCH NHẬN BIẾT                   │
--    ├────────────┼─────────────────┼───────────────────────────────────┤
--    │ 1-1        │ Chat ↔ Hóa đơn  │ PK = FK (tReceipts.id = tAIConv.id)│
--    │ 1-N        │ User → Wallets  │ FK từ con trỏ về cha              │
--    │ N-N        │ Roles ↔ Perms   │ Bảng trung gian (2 FK)            │
--    │ SELF-REF   │ Categories      │ parent_id → id (cùng bảng)        │
--    └────────────┴─────────────────┴───────────────────────────────────┘

-- 5. THUẬT NGỮ KỸ THUẬT
--    ┌─────────────────┬─────────────────────────────────────────────┐
--    │ THUẬT NGỮ      │ Ý NGHĨA & VÍ DỤ                            │
--    ├─────────────────┼─────────────────────────────────────────────┤
--    │ CONSTANTS      │ Giá trị cố định DB (CHECK constraint)       │
--    │                 │ VD: CHECK (source_type BETWEEN 1 AND 4)    │
--    ├─────────────────┼─────────────────────────────────────────────┤
--    │ ENUM (Java)    │ Hằng số Backend (package: com.smartmoney.enum)│
--    │                 │ VD: TransactionType.INCOME (DB value = 1)  │
--    ├─────────────────┼─────────────────────────────────────────────┤
--    │ BITMASK        │ Lưu nhiều option vào 1 INT (lũy thừa 2)     │
--    │                 │ VD: T2=1,T3=2,T4=4 → T2+T4 = 5 (1+4)       │
--    ├─────────────────┼─────────────────────────────────────────────┤
--    │ SOFT DELETE    │ Ẩn record (deleted=1) thay vì DELETE     │
--    │                 │ Áp dụng: tTransactions                     │
--    ├─────────────────┼─────────────────────────────────────────────┤
--    │ DTO            │ Data Transfer Object - Chỉ trả data cần    │
--    │                 │ VD: TransactionDTO (không trả Entity JPA)  │
--    └─────────────────┴─────────────────────────────────────────────┘

-- 6. QUY TẮC XỬ LÝ ĐẶC BIỆT
--    □ Xóa danh mục: Chuyển transaction sang danh mục khác hoặc xóa
--    □ Số dư âm: Cho phép (hiển thị màu đỏ + cảnh báo)

-- 7. TRIGGER - TỰ ĐỘNG HÓA
--    □ Tự cộng/trừ số dư ví khi có giao dịch mới/xóa
--    □ Tự cập nhật updated_at khi record thay đổi
--    □ Tự update current_amount của SavingGoals
--    -- Lưu ý: Trigger đơn giản, logic phức tạp xử lý ở Backend

-- 8. INDEX TỐI ƯU HIỆU NĂNG
--    □ Luôn có acc_id đầu trong composite index
--    □ Dùng INCLUDE cho column thường SELECT
--    VD: CREATE INDEX idx_trans_active ON tTransactions(acc_id, deleted) 
--        INCLUDE (amount, trans_date) WHERE deleted = 0

-- 9. QUY TRÌNH PHÁT TRIỂN
--    1. Đọc business rules (mục 3,6) trước khi code
--    2. Check constants/enum trong DB và Java
--    3. Mọi API phải validate acc_id của user đang login
--    4. Test với ít nhất 2 user (đảm bảo data isolation)

-- 10. COMMON MISTAKES CẦN TRÁNH
--     ❌ SELECT * (dùng column cụ thể)  ❌ N+1 query (dùng JOIN FETCH)
--     ❌ Hardcode số (dùng constant)    ❌ Không validate ownership
--     ❌ Gửi raw Entity ra API (dùng DTO) ❌ Quên WHERE acc_id = ?

-- 11. AI INTEGRATION NOTES
--     □ Chat Intent: 1=add_trans, 2=report, 3=budget, 4=chat, 5=remind
--     □ OCR Receipt: Google Vision API (free tier)
--     □ Voice: Google Speech-to-Text
--     □ AI Model: Ưu tiên Gemini API (free), backup OpenAI

-- 12. SECURITY CHECKLIST
--     □ Password hash với Bcrypt (cost 12) □ JWT expiration hợp lý
--     □ Input validation (SQL injection)   □ Rate limiting API login
--     □ HTTPS only                         □ CORS configuration

-- =======================================================================================================
-- 🎯 PHÂN CÔNG MODULE & TRÁCH NHIỆM
-- =======================================================================================================
-- MODULE 1: WEB/AUTH (Nam phụ trách)
--   Bảng: tAccounts, tRoles, tPermissions, tRolePermissions, tUserDevices, tNotifications
--   Nhiệm vụ:
--     - JWT Authentication & Spring Security
--     - Dashboard / Admin Frontend với biểu đồ thống kê
--     - Hệ thống nhận thông báo (tNotifications) trên thiết bị đã login lưu token của thiết bị pc, laptop, đt
--     - Quản lý đa thiết bị đăng nhập (tUserDevices)
--     - Frontend Admin Dashboard (React)
-- 
-- MODULE 2: BASIC CRUD (Nhật phụ trách)
--   Bảng: tWallets, tSavingGoals, tEvents, tBudgets, tBudgetCategories, tCurrencies
--   Nhiệm vụ:
--     - CRUDS cơ bản cho các bảng trên ( cả tWallet và tSavingGoals thực chất cũng là ví nhưng mục đích sử dụng khác nhau )
--     - Cung cấp API để Module 3 có cơ sở xử lý backend phần giao dịch
--     - Frontend EndUser cơ bản (React)
-- 
-- MODULE 3: TRANSACTION CORE (Phát - Leader phụ trách)
--   Bảng: tTransactions, tPlannedTransactions, tCategories, tDebts
--   Nhiệm vụ:
--     - Thiết kế database & Quản lý tổng thể
--     - Viết tài liệu dự án & Hướng dẫn nhóm
--     - Xử lý logic giao dịch phức tạp (thu/chi, định kỳ, nợ)
--     - Quản lý danh mục (tCategories) - cả system và user
-- 
-- MODULE 4: APP CLIENT (Cả nhóm cùng làm SAU KHI hoàn thành 3 module trên)
--   Nhiệm vụ:
--     - Ứng dụng di động
--     - Mobile UI/UX, Push Notifications
-- 
-- MODULE 5: AI INTEGRATION (Cả nhóm cùng làm SAU KHI hoàn thành 3 module trên)
--   Bảng: tAIConversations, tReceipts
--   Nhiệm vụ:
--     - AI Chat (text/voice)
--     - OCR xử lý hóa đơn
--     - Voice Processing
------------------------------------------------------------------------------------------
-- =======================================================================================================
-- 📌 LƯU Ý: Đây là guideline tham khảo, không bắt buộc áp dụng 100%
-- 📌 LƯU Ý: Nếu viết view, trigger, mọi chỉnh sửa vào database phải thông báo trước cho nhóm không tự ý thay đổi.
-- =======================================================================================================
GO

USE master;
GO

-- Xóa database cũ nếu tồn tại
IF EXISTS (SELECT * FROM sys.databases WHERE name = 'SmartMoney')
BEGIN
    ALTER DATABASE SmartMoney SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SmartMoney;
END
GO
-- TẠO DATABASE
CREATE DATABASE SmartMoney;
GO
USE SmartMoney
GO

-- ======================================================================
-- XÓA BẢNG THEO THỨ TỰ NGƯỢC (CON TRƯỚC, CHA SAU)
-- ======================================================================
DROP TABLE IF EXISTS tBudgetCategories;        -- [1]  Bảng trung gian (N-N) giữa tBudgets và tCategories
DROP TABLE IF EXISTS tPlannedTransactions;     -- [2]  Con của tAccounts(1-N) + tWallets(1-N) + tCategories(1-N)
DROP TABLE IF EXISTS tTransactions;            -- [3]  Con của tAccounts(1-N) + tWallets(1-N) + tCategories(1-N)
DROP TABLE IF EXISTS tReceipts;                -- [4]  Con của tAIConversations (quan hệ 1-1: PK = FK)
DROP TABLE IF EXISTS tAIConversations;         -- [5]  Con của tAccounts (1-N)
DROP TABLE IF EXISTS tNotifications;           -- [6]  Con của tAccounts (1-N)
DROP TABLE IF EXISTS tDebts;                   -- [7]  Con của tAccounts (1-N)
DROP TABLE IF EXISTS tBudgets;                 -- [8]  Con của tAccounts(1-N) + tWallets(1-N)
DROP TABLE IF EXISTS tSavingGoals;             -- [9]  Con của tAccounts (1-N)
DROP TABLE IF EXISTS tEvents;                  -- [10] Con của tAccounts (1-N)
DROP TABLE IF EXISTS tWallets;                 -- [11] Con của tAccounts(1-N) + tCurrencies(1-N)
DROP TABLE IF EXISTS tCategories;              -- [12] Con của tAccounts(1-N) + Tự tham chiếu chính nó
DROP TABLE IF EXISTS tUserDevices;             -- [13] Con của tAccounts (1-N)
DROP TABLE IF EXISTS tAccounts;                -- [14] Cha chính - Con của tRoles(1-N) và tCurrencies(1-N)
DROP TABLE IF EXISTS tRolePermissions;         -- [15] Bảng trung gian (N-N) giữa tRoles và tPermissions
DROP TABLE IF EXISTS tRoles;                   -- [16] Master data - Không phụ thuộc bảng nào
DROP TABLE IF EXISTS tPermissions;             -- [17] Master data - Không phụ thuộc bảng nào
DROP TABLE IF EXISTS tCurrencies;              -- [18] Master data - Xóa cuối cùng
GO
-- ======================================================================
-- 1. BẢNG QUYỀN HỆ THỐNG
-- ======================================================================
CREATE TABLE tPermissions(
    -- PRIMARY KEY
	id INT PRIMARY KEY IDENTITY(1,1),

    -- DATA COLUMNS
	per_code VARCHAR(50) UNIQUE NOT NULL,   -- Mã quyền động từ (VD: "CREATE_BUDGET", "VIEW_REPORT")
	per_name NVARCHAR(100) UNIQUE NOT NULL, -- Tên hiển thị
	module_group NVARCHAR(50) NOT NULL      -- Nhóm module (USER_CORE, ADMIN_CORE)
);
GO
-- Index: Tối ưu tìm kiếm quyền theo nhóm module cho Admin UI
CREATE INDEX idx_permissions_group ON tPermissions(module_group) INCLUDE (per_code, per_name);
GO

-- DỮ LIỆU MẪU: Quyền hệ thống
INSERT INTO tPermissions (per_code, per_name, module_group) VALUES 
('USER_STANDARD_MANAGE', N'Toàn quyền quản lý tài chính cá nhân cơ bản', 'USER_CORE'),
('ADMIN_SYSTEM_ALL',     N'Toàn quyền quản trị hệ thống và người dùng', 'ADMIN_CORE');
GO

-- ======================================================================
-- 2. BẢNG VAI TRÒ
-- ======================================================================
CREATE TABLE tRoles(
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),
    -- DATA COLUMNS
    role_code VARCHAR(50) UNIQUE NOT NULL,       -- Mã role cho code check (VD: "ROLE_USER", "ROLE_ADMIN")
    role_name NVARCHAR(100) UNIQUE NOT NULL      -- Tên role hiển thị UI (VD: "Quản trị viên", "Người dùng")
)
GO

-- Index: Tối ưu check role từ Backend
CREATE INDEX idx_role_code ON tRoles(role_code) INCLUDE (role_name);
GO

-- DỮ LIỆU MẪU: Vai trò
INSERT INTO tRoles (role_code, role_name) VALUES 
('ROLE_ADMIN', N'Quản trị viên'),
('ROLE_USER', N'Người dùng tiêu chuẩn');
GO

-- ======================================================================
-- 3. BẢNG TRUNG GIAN ROLE - PERMISSION (N-N)
-- ======================================================================
CREATE TABLE tRolePermissions(
    -- PRIMARY KEY (Composite)
    role_id INT NOT NULL,                        -- FK -> tRoles (N-N)
    per_id INT NOT NULL,                         -- FK -> tPermissions (N-N)
	PRIMARY KEY (role_id, per_id),               -- Composite PK

    -- FOREIGN KEYS
	CONSTRAINT FK_Role FOREIGN KEY (role_id) REFERENCES tRoles(id),
	CONSTRAINT FK_Permission FOREIGN KEY (per_id) REFERENCES tPermissions(id)
)
GO

-- Index: Tối ưu load quyền theo Role (dùng khi nạp Security Context)
CREATE INDEX idx_roleper_role ON tRolePermissions(role_id) INCLUDE (per_id);
GO

INSERT INTO tRolePermissions (role_id, per_id) VALUES 
(2, 1),  -- User có quyền quản lý tài chính cá nhân
(1, 2);  -- Admin có quyền toàn quyền hệ thống
GO

-- ======================================================================
-- 4. BẢNG TIỀN TỆ
-- ======================================================================
CREATE TABLE tCurrencies (
    -- PRIMARY KEY
    currency_code VARCHAR(10) PRIMARY KEY,       -- Mã tiền tệ (VD: VND, USD, EUR)
    
    -- DATA COLUMNS
    currency_name NVARCHAR(100) UNIQUE NOT NULL, -- Tên đầy đủ (VD: "Việt Nam Đồng")
    symbol NVARCHAR(10) NOT NULL,                -- Ký hiệu (VD: "₫", "$", "€")
    flag_url VARCHAR(500) UNIQUE NOT NULL        -- URL cờ quốc gia (dùng CDN)
);
GO

-- DỮ LIỆU MẪU: Tiền tệ
INSERT INTO tCurrencies (currency_code, currency_name, symbol, flag_url) VALUES 
-- Cường quốc & Chiến hữu
('VND', N'Việt Nam Đồng', N'₫', 'https://flagcdn.com/w40/vn.png'),
('CNY', N'Nhân dân tệ', N'¥', 'https://flagcdn.com/w40/cn.png'),
('RUB', N'Rúp Nga', N'₽', 'https://flagcdn.com/w40/ru.png'),
('CUP', N'Peso Cuba', N'₱', 'https://flagcdn.com/w40/cu.png'),
('KPW', N'Won Triều Tiên', N'₩', 'https://flagcdn.com/w40/kp.png'),
('AOA', N'Kwanza Angola', N'Kz', 'https://flagcdn.com/w40/ao.png'),

-- Khu vực Đông Á
('HKD', N'Đô la Hồng Kông', N'$', 'https://flagcdn.com/w40/hk.png'),
('MOP', N'Pataca Macao', N'MOP$', 'https://flagcdn.com/w40/mo.png'),
('TWD', N'Đô la Đài Loan', N'$', 'https://flagcdn.com/w40/tw.png'),
('JPY', N'Yên Nhật', N'¥', 'https://flagcdn.com/w40/jp.png'),
('KRW', N'Won Hàn Quốc', N'₩', 'https://flagcdn.com/w40/kr.png'),

-- Đông Âu & Trung Á
('UAH', N'Hryvnia Ukraina', N'₴', 'https://flagcdn.com/w40/ua.png'),
('BYN', N'Rúp Belarus', N'Br', 'https://flagcdn.com/w40/by.png'),
('KZT', N'Tenge Kazakhstan', N'₸', 'https://flagcdn.com/w40/kz.png'),
('PLN', N'Zloty Ba Lan', N'zł', 'https://flagcdn.com/w40/pl.png'),

-- Phương Tây
('USD', N'Đô la Mỹ', N'$', 'https://flagcdn.com/w40/us.png'),
('EUR', N'Euro (Khối EU)', N'€', 'https://flagcdn.com/w40/eu.png'),
('GBP', N'Bảng Anh', N'£', 'https://flagcdn.com/w40/gb.png'),
('CHF', N'Franc Thụy Sĩ', N'CHF', 'https://flagcdn.com/w40/ch.png'),
('CAD', N'Đô la Canada', N'$', 'https://flagcdn.com/w40/ca.png'),
('AUD', N'Đô la Úc', N'$', 'https://flagcdn.com/w40/au.png'),

-- Nam Mỹ & Nam Á
('ARS', N'Peso Argentina', N'$', 'https://flagcdn.com/w40/ar.png'),
('BRL', N'Real Brazil', N'R$', 'https://flagcdn.com/w40/br.png'),
('INR', N'Rupee Ấn Độ', N'₹', 'https://flagcdn.com/w40/in.png'),

-- Trung Đông & Châu Phi
('SAR', N'Riyal Saudi Arabia', N'﷼', 'https://flagcdn.com/w40/sa.png'),
('AED', N'Dirham UAE', N'د.إ', 'https://flagcdn.com/w40/ae.png'),
('ILS', N'Shekel Israel', N'₪', 'https://flagcdn.com/w40/il.png'),
('EGP', N'Bảng Ai Cập', N'E£', 'https://flagcdn.com/w40/eg.png'),
('NGN', N'Naira Nigeria', N'₦', 'https://flagcdn.com/w40/ng.png'),
('ZAR', N'Rand Nam Phi', N'R', 'https://flagcdn.com/w40/za.png'),

-- Đông Nam Á (ASEAN)
('LAK', N'Kip Lào', N'₭', 'https://flagcdn.com/w40/la.png'),
('KHR', N'Riel Campuchia', N'៛', 'https://flagcdn.com/w40/kh.png'),
('THB', N'Baht Thái Lan', N'฿', 'https://flagcdn.com/w40/th.png'),
('SGD', N'Đô la Singapore', N'$', 'https://flagcdn.com/w40/sg.png'),
('MYR', N'Ringgit Malaysia', N'RM', 'https://flagcdn.com/w40/my.png'),
('IDR', N'Rupiah Indonesia', N'Rp', 'https://flagcdn.com/w40/id.png'),
('PHP', N'Peso Philippines', N'₱', 'https://flagcdn.com/w40/ph.png'),
('MMK', N'Kyat Myanmar', N'K', 'https://flagcdn.com/w40/mm.png'),
('BND', N'Đô la Brunei', N'$', 'https://flagcdn.com/w40/bn.png');
GO

-- ======================================================================
-- 5. BẢNG TÀI KHOẢN NGƯỜI DÙNG
-- ======================================================================
CREATE TABLE tAccounts (
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),
    
    -- FOREIGN KEYS
    role_id INT NOT NULL,                        -- FK -> tRoles (N-1)
    currency VARCHAR(10) DEFAULT 'VND',          -- FK -> tCurrencies (N-1) Tiền tệ mặc định
    
    -- DATA COLUMNS
    acc_phone VARCHAR(20) NULL,                  -- Số điện thoại (NULL nếu đăng ký bằng email)
    acc_email VARCHAR(100) NULL,                 -- Email (NULL nếu đăng ký bằng SĐT)
    hash_password VARCHAR(255) NOT NULL,         -- Mật khẩu đã hash (BCrypt/Argon2)
    avatar_url VARCHAR(2048) NULL,               -- URL avatar (upload hoặc CDN)
    locked BIT DEFAULT 0 NOT NULL,            -- 0: Active | 1: Locked (không thể login)
    
    -- METADATA
    created_at DATETIME DEFAULT GETDATE() NOT NULL,
    updated_at DATETIME DEFAULT GETDATE(),
    
    -- CONSTRAINTS
    CONSTRAINT CHK_Account_Identity CHECK (acc_phone IS NOT NULL OR acc_email IS NOT NULL), -- Bắt buộc có 1 trong 2

    CONSTRAINT FK_Account_Role FOREIGN KEY (role_id) REFERENCES tRoles(id),
    CONSTRAINT FK_Account_Currency FOREIGN KEY (currency) REFERENCES tCurrencies(currency_code)
);
GO

-- Index: Unique cho Phone (chặn trùng lặp)
CREATE UNIQUE NONCLUSTERED INDEX idx_unique_acc_phone ON tAccounts(acc_phone) 
WHERE acc_phone IS NOT NULL;

-- Index: Unique cho Email (chặn trùng lặp)
CREATE UNIQUE NONCLUSTERED INDEX idx_unique_acc_email ON tAccounts(acc_email) 
WHERE acc_email IS NOT NULL;

-- Index: Tối ưu Admin search User theo status và role
CREATE INDEX idx_accounts_admin ON tAccounts(locked, role_id, created_at DESC) 
INCLUDE (acc_phone, acc_email, avatar_url, currency);

-- Index: Tối ưu lọc User theo tiền tệ cho thống kê
CREATE INDEX idx_accounts_currency ON tAccounts(currency, created_at DESC);
GO

-- DỮ LIỆU MẪU: Tài khoản
INSERT INTO tAccounts (role_id, acc_phone, acc_email, hash_password, avatar_url, currency, locked) VALUES 
(1, '0901234567', 'admin@smartmoney.vn', '$2a$10$tF5hUn6YqBEMNkVi/0SlhOKYXEIzQwoGMXY1wIcRqRWSiG2Z.Id5K', 'https://api.dicebear.com/7.x/avataaars/svg?seed=AdminPRO', 'VND', 0),
(2, '0912345678', 'mai.tran@gmail.com', '$2a$10$tF5hUn6YqBEMNkVi/0SlhOKYXEIzQwoGMXY1wIcRqRWSiG2Z.Id5K', 'https://api.dicebear.com/7.x/avataaars/svg?seed=Mai', 'VND', 1),
(2, '0987654321', 'nam.le@yahoo.com', '$2a$10$tF5hUn6YqBEMNkVi/0SlhOKYXEIzQwoGMXY1wIcRqRWSiG2Z.Id5K', 'https://api.dicebear.com/7.x/avataaars/svg?seed=Nam', 'VND', 0);
GO

-- ======================================================================
-- 6. BẢNG THIẾT BỊ NGƯỜI DÙNG (1-N với tAccounts)
-- ======================================================================
CREATE TABLE tUserDevices (
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),
    
    -- FOREIGN KEYS
    acc_id INT NOT NULL,                         -- FK -> tAccounts (N-1)
    
    -- DATA COLUMNS
    device_token VARCHAR(500) NOT NULL,          -- Firebase/APNs token (UNIQUE)

    refresh_token VARCHAR(512) NULL,             -- JWT Refresh Token (hash)
    refresh_token_expired_at DATETIME NULL,      -- Thời hạn Refresh Token

    device_type VARCHAR(50) NOT NULL,            -- VD: "iOS", "Android", "Chrome_Windows"
    device_name NVARCHAR(100) NULL,              -- VD: "iPhone 15 Pro", "Samsung S24"
    ip_address VARCHAR(45) NULL,                 -- IPv4/IPv6 cuối cùng (cảnh báo đăng nhập lạ)
    logged_in BIT DEFAULT 1 NOT NULL,         -- 0: Đã logout | 1: Còn session
    last_active DATETIME DEFAULT GETDATE() NOT NULL, -- Thời gian cuối active (dùng tính Online)
    
    -- CONSTRAINTS
    CONSTRAINT FK_UserDevices_Account FOREIGN KEY (acc_id) REFERENCES tAccounts(id)     
);
GO
/* CÔNG THỨC CHECK ONLINE (Dành cho Dev Backend/Frontend):
  Online = (logged_in == 1) AND (CurrentTime - last_active < 5 phút)
  
  Lý do: logged_in chỉ cho biết User chưa bấm "Đăng xuất". 
  Còn last_active mới cho biết User có thực sự đang cầm máy hay không.
*/

--  Index: Unique cho Device Token (chặn trùng lặp)
CREATE UNIQUE NONCLUSTERED INDEX idx_unique_device_token ON tUserDevices(device_token) WHERE device_token IS NOT NULL;
-- Index: Tối ưu validate Refresh Token nhanh
CREATE INDEX idx_devices_refresh ON tUserDevices(refresh_token, refresh_token_expired_at) WHERE refresh_token IS NOT NULL;
-- Index: Tối ưu query danh sách thiết bị Online của User
CREATE INDEX idx_devices_presence ON tUserDevices(acc_id, logged_in, last_active DESC) INCLUDE (device_name, device_type);
-- Index: Tối ưu Worker dọn token hết hạn
CREATE INDEX idx_devices_expired_token ON tUserDevices(refresh_token_expired_at) WHERE refresh_token IS NOT NULL;
GO

-- ======================================================================
-- 7. BẢNG DANH MỤC THU/CHI (Tự tham chiếu: 1-N với chính nó)
-- ======================================================================
-- Nếu người dùng muốn xóa danh mục thì sẽ có 2 hướng ( Xóa hẳn và gồm lịch sử giao dịch hoặc chọn gộp sang một danh mục khác và xóa danh mục này )
CREATE TABLE tCategories (
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),
    
    -- FOREIGN KEYS
    acc_id INT NULL,                             -- FK -> tAccounts (N-1) | NULL = System Category
    parent_id INT NULL,                          -- FK -> tCategories (1-N) | NULL = Root Category
    
    -- DATA COLUMNS
    ctg_name NVARCHAR(100) NOT NULL,             -- Tên danh mục (VD: "Ăn uống", "Lương")
    ctg_type BIT NOT NULL,                       -- 0: Chi tiêu | 1: Thu nhập
    ctg_icon_url VARCHAR(2048) NULL,             -- Icon SVG hoặc URL (VD: "icon_food.svg")
    
    -- CONSTRAINTS
    CONSTRAINT FK_Categories_Account FOREIGN KEY (acc_id) REFERENCES tAccounts(id),
    CONSTRAINT FK_Categories_Parent FOREIGN KEY (parent_id) REFERENCES tCategories(id) -- Tự tham chiếu
);
GO

-- Index: Tối ưu Backend check danh mục System
CREATE INDEX idx_system_category_check ON tCategories(ctg_name) WHERE acc_id IS NULL AND parent_id IS NULL;
-- Index: Tối ưu query danh mục theo User và Parent
CREATE INDEX idx_categories_lookup ON tCategories(acc_id, parent_id, ctg_type) INCLUDE (ctg_name, ctg_icon_url);
-- Chặn User tạo 2 mục con (vd: "Tiền trà đá", "Tiền trà đá") trong cùng một mục cha.
CREATE UNIQUE NONCLUSTERED INDEX idx_unique_sub_category ON tCategories(acc_id, parent_id, ctg_name, ctg_type) WHERE parent_id IS NOT NULL;
-- Chặn User tạo 2 mục cha (vd: "Ăn uống", "Ăn uống").
CREATE UNIQUE NONCLUSTERED INDEX idx_unique_user_root ON tCategories(acc_id, ctg_name, ctg_type) 
WHERE parent_id IS NULL AND acc_id IS NOT NULL;
-- Index Unique: Bảo vệ danh mục gốc System không bị trùng
CREATE UNIQUE NONCLUSTERED INDEX idx_unique_root_category ON tCategories(ctg_name, ctg_type) 
WHERE parent_id IS NULL AND acc_id IS NULL;
-- Index Unique: Bảo vệ danh mục con System không bị trùng
CREATE UNIQUE NONCLUSTERED INDEX idx_unique_system_sub_category ON tCategories(parent_id, ctg_name, ctg_type) WHERE parent_id IS NOT NULL AND acc_id IS NULL;
-- Ngăn User tạo danh mục Gốc trùng tên với danh mục Gốc của Hệ thống ( viết trong backend )

/* HƯỚNG DẪN CHO BACKEND hoặc dùng trigger (IMPORTANT):
   - ĐIỀU KIỆN: "User không được tạo danh mục Gốc trùng tên với System".
   - BACKEND CẦN CHECK: Trước khi lưu danh mục Gốc cho User, hãy kiểm tra xem 'ctg_name' 
     đã tồn tại trong các dòng (acc_id IS NULL AND parent_id IS NULL) chưa. 
     Nếu có -> Báo lỗi cho người dùng không được tạo trùng danh mục hệ thống
*/

GO
-- Chèn danh mục hệ thống (acc_id = NULL)
-- ==========================================================
-- BƯỚC 1: CHÈN CÁC NHÓM CHA (ROOT) - ĐỊNH DANH CẤP CAO NHẤT
-- ==========================================================
-- 1.1 NHÓM CHI TIÊU (EXPENSE = 0)
INSERT INTO tCategories (acc_id, parent_id, ctg_name, ctg_type, ctg_icon_url) VALUES  
 (NULL, NULL, N'Ăn uống', 0, 'icon_food.svg')
,(NULL, NULL, N'Bảo hiểm', 0, 'icon_insurance.svg')
,(NULL, NULL, N'Các chi phí khác', 0, 'icon_other_expense.svg')
,(NULL, NULL, N'Đầu tư', 0, 'icon_invest.svg')
,(NULL, NULL, N'Di chuyển', 0, 'icon_transport.svg')
,(NULL, NULL, N'Gia đình', 0, 'icon_family.svg')
,(NULL, NULL, N'Giải trí', 0, 'icon_entertainment.svg')
,(NULL, NULL, N'Giáo dục', 0, 'icon_education.svg')
,(NULL, NULL, N'Hoá đơn & Tiện ích', 0, 'icon_utilities.svg')
,(NULL, NULL, N'Mua sắm', 0, 'icon_shopping.svg')
,(NULL, NULL, N'Quà tặng & Quyên góp', 0, 'icon_gift.svg')
,(NULL, NULL, N'Sức khỏe', 0, 'icon_health.svg')
,(NULL, NULL, N'Tiền chuyển đi', 0, 'icon_transfer_out.svg')
,(NULL, NULL, N'Trả lãi', 0, 'icon_interest_pay.svg');

-- 1.2 NHÓM THU NHẬP (INCOME = 1)
INSERT INTO tCategories (acc_id, parent_id, ctg_name, ctg_type, ctg_icon_url) VALUES  
 (NULL, NULL, N'Lương', 1, 'icon_salary.svg')
,(NULL, NULL, N'Thu lãi', 1, 'icon_interest_receive.svg')
,(NULL, NULL, N'Thu nhập khác', 1, 'icon_other_income.svg')
,(NULL, NULL, N'Tiền chuyển đến', 1, 'icon_transfer_in.svg');

-- 1.3 NHÓM VAY / NỢ
INSERT INTO tCategories (acc_id, parent_id, ctg_name, ctg_type, ctg_icon_url) VALUES  
 (NULL, NULL, N'Cho vay', 0, 'icon_loan_out.svg')
,(NULL, NULL, N'Đi vay', 1, 'icon_loan_in.svg')
,(NULL, NULL, N'Thu nợ', 1, 'icon_debt_collection.svg')
,(NULL, NULL, N'Trả nợ', 0, 'icon_debt_repayment.svg');
GO -- Kết thúc phiên làm việc 1 để SQL lưu ID các nhóm Cha

-- ==========================================================
-- BƯỚC 2: CHÈN CÁC NHÓM CON (SUB-CATEGORIES) - LIÊN KẾT CHA
-- ==========================================================
-- Chèn con cho nhóm CHI TIÊU
INSERT INTO tCategories (acc_id, parent_id, ctg_name, ctg_type, ctg_icon_url)
SELECT NULL, p.id, v.new_name, p.ctg_type, v.icon
FROM (VALUES  
    (N'Di chuyển', N'Bảo dưỡng xe', 'icon_car_repair.svg'),
    (N'Gia đình', N'Dịch vụ gia đình', 'icon_home_service.svg'),
    (N'Gia đình', N'Sửa & trang trí nhà', 'icon_home_decor.svg'),
    (N'Gia đình', N'Vật nuôi', 'icon_pets.svg'),
    (N'Giải trí', N'Dịch vụ trực tuyến', 'icon_online_service.svg'),
    (N'Giải trí', N'Vui - chơi', 'icon_travel.svg'),
    (N'Hoá đơn & Tiện ích', N'Hoá đơn điện', 'icon_electricity.svg'),
    (N'Hoá đơn & Tiện ích', N'Hoá đơn điện thoại', 'icon_phone_bill.svg'),
    (N'Hoá đơn & Tiện ích', N'Hoá đơn gas', 'icon_gas.svg'),
    (N'Hoá đơn & Tiện ích', N'Hoá đơn internet', 'icon_internet.svg'),
    (N'Hoá đơn & Tiện ích', N'Hoá đơn nước', 'icon_water.svg'),
    (N'Hoá đơn & Tiện ích', N'Hoá đơn tiện ích khác', 'icon_other_bill.svg'),
    (N'Hoá đơn & Tiện ích', N'Hoá đơn TV', 'icon_tv.svg'),
    (N'Hoá đơn & Tiện ích', N'Thuê nhà', 'icon_rent.svg'),
    (N'Mua sắm', N'Đồ dùng cá nhân', 'icon_personal_item.svg'),
    (N'Mua sắm', N'Đồ gia dụng', 'icon_home_appliance.svg'),
    (N'Mua sắm', N'Làm đẹp', 'icon_beauty.svg'),
    (N'Sức khỏe', N'Khám sức khoẻ', 'icon_medical.svg'),
    (N'Sức khỏe', N'Thể dục thể thao', 'icon_sport.svg')
) AS v(parent_name, new_name, icon)
JOIN tCategories p ON p.ctg_name = v.parent_name AND p.parent_id IS NULL;
GO

-- ======================================================================
-- 8. BẢNG VÍ (1-N với tAccounts)
-- ======================================================================
CREATE TABLE tWallets (
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),
    
    -- FOREIGN KEYS
    acc_id INT NOT NULL,                         -- FK -> tAccounts (N-1)
    currency VARCHAR(10) DEFAULT 'VND',          -- FK -> tCurrencies (N-1)
    -- them anh con thieu
     goal_image_url VARCHAR(2048) NULL,           -- Hình ảnh ví
    -- DATA COLUMNS
    wallet_name NVARCHAR(100) NOT NULL,          -- VD: "Tiền mặt", "Vietcombank", "Momo"
    balance DECIMAL(18,2) DEFAULT 0,             -- Số dư hiện tại (tự động tính từ Transactions)
    notified BIT DEFAULT 1 NOT NULL,          -- 0: Tắt thông báo | 1: Bật thông báo
    reportable BIT DEFAULT 1 NOT NULL,        -- 0: Không tính vào báo cáo | 1: Tính vào Dashboard
    
    -- CONSTRAINTS
    CONSTRAINT FK_Wallets_Account FOREIGN KEY (acc_id) REFERENCES tAccounts(id),
    CONSTRAINT FK_Wallets_Currency FOREIGN KEY (currency) REFERENCES tCurrencies(currency_code)
);
GO

-- Index: Tối ưu load danh sách Ví của User
CREATE INDEX idx_wallets_user ON tWallets(acc_id, reportable) INCLUDE (wallet_name, balance, currency, notified);
GO

-- DỮ LIỆU MẪU: Ví
INSERT INTO tWallets (acc_id, wallet_name, balance, currency) VALUES 
(1, N'Tiền mặt', 5000000, 'VND'),
(2, N'Vietcombank', 15000000, 'VND');
GO

-- ======================================================================
-- 9. BẢNG MỤC TIÊU TIẾT KIỆM (1-N với tAccounts)
-- ======================================================================
CREATE TABLE tSavingGoals (
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),
    
    -- FOREIGN KEYS
    acc_id INT NOT NULL,                         -- FK -> tAccounts (N-1)
    currency VARCHAR(10) DEFAULT 'VND',          -- FK -> tCurrencies (N-1)
    
    -- DATA COLUMNS
    goal_name NVARCHAR(200) NOT NULL,            -- VD: "Mua iPhone 15 Pro Max", "Quỹ khẩn cấp"
    target_amount DECIMAL(18,2) NOT NULL,        -- Số tiền mục tiêu
    current_amount DECIMAL(18,2) DEFAULT 0,      -- Số tiền đã tiết kiệm
    goal_image_url VARCHAR(2048) NULL,           -- Hình ảnh mục tiêu (VD: ảnh iPhone)
    begin_date DATE DEFAULT GETDATE(),           -- Ngày bắt đầu
    end_date DATE NOT NULL,                      -- Ngày kết thúc
    goal_status TINYINT DEFAULT 1 NOT NULL,        -- 1: Active | 2: Completed | 3: Cancelled
    notified BIT DEFAULT 1 NOT NULL,          -- 0: Tắt thông báo | 1: Bật thông báo
    reportable BIT DEFAULT 1 NOT NULL,        -- 0: Không tính vào báo cáo | 1: Tính vào Dashboard
    finished BIT DEFAULT 0,                   -- 0: Đang diễn ra | 1: Đã kết thúc
    
    -- CONSTRAINTS
    CONSTRAINT CHK_SavingGoals_Amount CHECK (target_amount > 0 AND current_amount >= 0),
    CONSTRAINT CHK_SavingGoals_Progress CHECK (current_amount <= target_amount),
    CONSTRAINT CHK_SavingGoals_Dates CHECK (end_date >= begin_date),
    CONSTRAINT CHK_SavingGoals_Status CHECK (goal_status IN (1, 2, 3)),

    CONSTRAINT FK_SavingGoals_Account FOREIGN KEY (acc_id) REFERENCES tAccounts(id),
    CONSTRAINT FK_SavingGoals_Currency FOREIGN KEY (currency) REFERENCES tCurrencies(currency_code)
);
GO

-- Index: Tối ưu Dashboard và Báo cáo tổng quát
CREATE INDEX idx_saving_reportable ON tSavingGoals(acc_id, reportable, goal_status, finished) INCLUDE (current_amount, target_amount, end_date, currency);
-- Index: Tối ưu hiển thị mục tiêu đang Active
CREATE INDEX idx_saving_active ON tSavingGoals(acc_id, goal_status, finished) INCLUDE (goal_name, current_amount, target_amount, end_date);
GO

-- DỮ LIỆU MẪU: Mục tiêu tiết kiệm
INSERT INTO tSavingGoals (acc_id, goal_name, target_amount, current_amount, end_date) VALUES 
(2, N'Mua iPhone 15', 25000000, 5000000, '2027-12-31');
GO

-- ======================================================================
-- 10. BẢNG SỰ KIỆN (1-N với tAccounts)
-- ======================================================================
CREATE TABLE tEvents (
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),
    
    -- FOREIGN KEYS
    acc_id INT NOT NULL,                         -- FK -> tAccounts (N-1)
    currency VARCHAR(10) DEFAULT 'VND',          -- FK -> tCurrencies (N-1)
    
    -- DATA COLUMNS
    event_name NVARCHAR(200) NOT NULL,           -- VD: "Đám cưới", "Du lịch Đà Lạt"
    event_icon_url NVARCHAR(2048) DEFAULT 'icon_event_default.svg',
    begin_date DATE DEFAULT GETDATE(),           -- Ngày bắt đầu sự kiện
    end_date DATE NOT NULL,                      -- Ngày kết thúc sự kiện
    finished BIT DEFAULT 0,                   -- 0: Đang diễn ra | 1: Đã kết thúc
    
    -- CONSTRAINTS
    CONSTRAINT CHK_Events_Dates CHECK (end_date >= begin_date),
    CONSTRAINT FK_Events_Account FOREIGN KEY (acc_id) REFERENCES tAccounts(id) ON DELETE CASCADE,
    CONSTRAINT FK_Events_Currency FOREIGN KEY (currency) REFERENCES tCurrencies(currency_code)
);
GO

-- Index: Tối ưu tìm kiếm sự kiện đang chạy để gán vào giao dịch
CREATE INDEX idx_events_active ON tEvents(acc_id, finished, currency) 
INCLUDE (event_name, begin_date, end_date);

-- Index: Tối ưu hiển thị danh sách tất cả sự kiện ở màn quản lý
CREATE INDEX idx_events_all ON tEvents(acc_id, begin_date DESC) 
INCLUDE (event_name, finished, event_icon_url);
GO

-- DỮ LIỆU MẪU: Sự kiện
INSERT INTO tEvents (acc_id, event_name, end_date) VALUES 
(2, N'Du lịch Đà Nẵng', '2029-08-30');
GO

-- ======================================================================
-- 11. BẢNG SỔ NỢ (1-N với tAccounts)
-- ======================================================================
CREATE TABLE tDebts (
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),
    
    -- FOREIGN KEYS
    acc_id INT NOT NULL,                         -- FK -> tAccounts (N-1)
    
    -- DATA COLUMNS
    debt_type BIT NOT NULL,                      -- 0: Cần Trả (Đi vay) | 1: Cần Thu (Cho vay)
    total_amount DECIMAL(18,2) NOT NULL,         -- Tổng số tiền ban đầu
    remain_amount DECIMAL(18,2) NOT NULL,        -- Số tiền còn lại (giảm dần khi trả/thu)
    due_date DATETIME NULL,                      -- Ngày hẹn trả (dùng để nhắc nhở)
    note NVARCHAR(500),                          -- Ghi chú (VD: "Vay bạn A mua xe")
    finished BIT DEFAULT 0 NOT NULL,          -- 0: Đang nợ | 1: Đã hoàn thành
    created_at DATETIME DEFAULT GETDATE(),       -- Ngày tạo khoản nợ
    
    -- CONSTRAINTS
    CONSTRAINT CHK_Debts_TotalAmount CHECK (total_amount > 0),
    CONSTRAINT CHK_Debts_RemainLogic CHECK (remain_amount >= 0 AND remain_amount <= total_amount),
    CONSTRAINT FK_Debts_Account FOREIGN KEY (acc_id) REFERENCES tAccounts(id) ON DELETE CASCADE
);
GO

-- Index: Tối ưu Tab Cần Thu/Trả theo User và loại
CREATE INDEX idx_debts_active ON tDebts(acc_id, debt_type, finished, due_date) INCLUDE (remain_amount, total_amount, note);

-- Index: Tối ưu tính tổng nợ cho Báo cáo/Dashboard
CREATE INDEX idx_debts_reportable ON tDebts(acc_id, finished) INCLUDE (remain_amount, debt_type);

-- Index: Tối ưu lọc sổ nợ theo thời gian tạo
CREATE INDEX idx_debts_created ON tDebts(acc_id, created_at DESC) WHERE finished = 0;
GO

-- DỮ LIỆU MẪU: Sổ nợ
INSERT INTO tDebts (acc_id, debt_type, total_amount, remain_amount, due_date, note) VALUES 
(2, 1, 500000, 500000, '2029-07-30', N'Cho bạn A vay');
GO

-----------------------------------------------------------------------------------------------------------------------------
-- tAIConversations 1-1 tReceipts nếu xác nhận có hóa đơn thì mới tạo hóa đơn khóa chính. Hóa đơn là khóa chính của chat
-- ======================================================================
-- 12. BẢNG LỊCH SỬ CHAT AI (1-N với tAccounts)
-- ======================================================================
CREATE TABLE tAIConversations (
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),
    
    -- FOREIGN KEYS
    acc_id INT NOT NULL,                         -- FK -> tAccounts (N-1)
    
    -- DATA COLUMNS
    message_content NVARCHAR(MAX) NOT NULL,      -- Nội dung tin nhắn
    sender_type BIT NOT NULL,                    -- 0: User nhắn | 1: AI phản hồi
    intent TINYINT,                              -- 1: add_transaction | 2: report_query | 3: set_budget | 4: general_chat | 5: remind_task
    attachment_url NVARCHAR(500) NULL,           -- URL file đính kèm (hình ảnh hóa đơn/voice)
    attachment_type TINYINT NULL,                -- 1: image | 2: voice | NULL: chat text
    created_at DATETIME DEFAULT GETDATE(),       -- Thời gian chat 

    -- CONSTRAINTS    
    
    --1. Thêm chi tiêu/thu nhập
    --2. Hỏi về báo cáo, số dư
    --3. Thiết lập hạn mức
    --4. Tán gẫu hoặc hỏi đáp chung
    --5. Nhắc nhở    
    CONSTRAINT CHK_AIConversations_Intent CHECK (intent BETWEEN 1 AND 5),
	CONSTRAINT CHK_AIConversations_Attachment_Type CHECK (attachment_type IN (1, 2)), -- chat thường là null

	CONSTRAINT CHK_AIConversations_Attach_Logic CHECK (
		(attachment_type = 1 AND attachment_url IS NOT NULL) OR     -- Có ảnh thì bắt buộc phải có URL
		(attachment_type = 2 AND attachment_url IS NULL) OR         -- Lệnh giọng nói thì URL để NULL (không lưu file)
		(attachment_type IS NULL AND attachment_url IS NULL)        -- Chat text thì cả 2 NULL
	),

	CONSTRAINT FK_AIConversations_Account FOREIGN KEY (acc_id) REFERENCES tAccounts(id),
);
GO

-- Index: Tối ưu load lịch sử chat của User theo thời gian
CREATE INDEX idx_ai_chat_user ON tAIConversations(acc_id, created_at DESC) INCLUDE (message_content, sender_type, intent);

-- Index: Tối ưu phân loại chat theo mục đích (intent)
CREATE INDEX idx_ai_intent ON tAIConversations(acc_id, intent, created_at DESC) INCLUDE (message_content, sender_type, attachment_type);
GO

-- DỮ LIỆU MẪU: Chat AI
INSERT INTO tAIConversations (acc_id, message_content, sender_type, intent) VALUES 
(2, N'Tôi đã chi 100k ăn sáng', 0, 1),
(2, N'Đã ghi nhận giao dịch ăn sáng 100k', 1, 1);
GO

-- ======================================================================
-- 13. BẢNG HÓA ĐƠN QUÉT (1-1 với tAIConversations)
-- ======================================================================
CREATE TABLE tReceipts (
    -- PRIMARY KEY (= Foreign Key)
    id INT PRIMARY KEY,                          -- FK -> tAIConversations (1-1)
    
    -- FOREIGN KEYS
    acc_id INT NOT NULL,                         -- FK -> tAccounts (N-1)
    
    -- DATA COLUMNS
    image_url NVARCHAR(500) NOT NULL,            -- URL ảnh hóa đơn (upload lên Cloud)
    raw_ocr_text NVARCHAR(MAX) NULL,             -- Text gốc từ OCR
    processed_data NVARCHAR(MAX) NULL DEFAULT '{}',    -- Dữ liệu đã parse (JSON format)
    receipt_status NVARCHAR(20) DEFAULT 'pending' NOT NULL, -- pending | processed | error
    created_at DATETIME DEFAULT GETDATE() NOT NULL,

    -- CONSTRAINTS	
    CONSTRAINT CHK_Receipt_Status CHECK (receipt_status IN ('pending', 'processed', 'error')),
    
    -- Check logic: Đã xong thì phải có dữ liệu
    CONSTRAINT CHK_Receipt_Processed_Logic CHECK (
        (receipt_status = 'processed' AND processed_data IS NOT NULL) 
        OR (receipt_status <> 'processed')
    ),

	CONSTRAINT FK_Receipts_Account FOREIGN KEY (acc_id) REFERENCES tAccounts(id),
	CONSTRAINT FK_Receipts_Chat FOREIGN KEY (id) REFERENCES tAIConversations(id) ON DELETE CASCADE
);
GO
-- Index: Tối ưu lọc hóa đơn chờ xử lý (pending) của User
CREATE INDEX idx_receipts_pending ON tReceipts(acc_id, receipt_status, created_at DESC) 
WHERE receipt_status = 'pending';

-- Index: Tối ưu query hóa đơn theo User và trạng thái
CREATE INDEX idx_receipts_user ON tReceipts(acc_id, receipt_status, created_at DESC) 
INCLUDE (image_url, raw_ocr_text);
GO
-----------------------------------------------------------------------------------------------------------------------------

-- ======================================================================
-- 14. BẢNG NGÂN SÁCH (1-N với tAccounts)
-- ======================================================================
CREATE TABLE tBudgets (
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),
    
    -- FOREIGN KEYS
    acc_id INT NOT NULL,                         -- FK -> tAccounts (N-1)
    wallet_id INT NULL,                      -- FK -> tWallets (N-1) Ngân sách rút từ ví nào
    
    -- DATA COLUMNS
    amount DECIMAL(18,2) NOT NULL,               -- Giới hạn ngân sách
    begin_date DATE DEFAULT GETDATE() NOT NULL,  -- Ngày bắt đầu chu kỳ
    end_date DATE NOT NULL,                      -- Ngày kết thúc chu kỳ
    all_categories BIT DEFAULT 0,             -- 0: Theo danh mục cụ thể | 1: Tất cả Chi tiêu
    repeating BIT DEFAULT 0,                  -- 0: Một lần | 1: Tự động gia hạn
    
    -- CONSTRAINTS
    CONSTRAINT CHK_Budgets_Amount CHECK (amount > 0),
    CONSTRAINT CHK_Budgets_Dates CHECK (end_date >= begin_date),
    CONSTRAINT FK_Budgets_Account FOREIGN KEY (acc_id) REFERENCES tAccounts(id),
    CONSTRAINT FK_Budgets_Wallet FOREIGN KEY (wallet_id) REFERENCES tWallets(id) ON DELETE CASCADE
);
GO

-- Code back end
-- CHẶN TRÙNG NGÂN SÁCH: Một User không thể có 2 ngân sách cho 1 danh mục trong cùng 1 khoảng thời gian
-- Lưu ý: Backend cần check logic ngày tháng, còn DB chặn trùng lặp tuyệt đối category cho chắc ăn.
--CREATE UNIQUE NONCLUSTERED INDEX idx_unique_budget_period ON tBudgets(acc_id, ctg_id, begin_date, end_date);

-- Index: Tối ưu query ngân sách theo User và chu kỳ
CREATE INDEX idx_budget_lookup ON tBudgets(acc_id, begin_date, end_date, all_categories) INCLUDE (amount, wallet_id, repeating);
GO

-- DỮ LIỆU MẪU: Ngân sách
--INSERT INTO tBudgets VALUES()
--GO

-- ======================================================================
-- 15. BẢNG TRUNG GIAN BUDGET - CATEGORY (N-N)
-- ======================================================================
CREATE TABLE tBudgetCategories (
    -- PRIMARY KEY (Composite)
    budget_id INT NOT NULL,                      -- FK -> tBudgets (N-N)
    ctg_id INT NOT NULL,                         -- FK -> tCategories (N-N)
    PRIMARY KEY (budget_id, ctg_id),
    
    -- FOREIGN KEYS
    CONSTRAINT FK_BudgetCategories_Budget FOREIGN KEY (budget_id) REFERENCES tBudgets(id) ON DELETE CASCADE,
    CONSTRAINT FK_BudgetCategories_Category FOREIGN KEY (ctg_id) REFERENCES tCategories(id) ON DELETE CASCADE
);
GO

-- Index: Tối ưu query ngược từ Category -> Budgets
CREATE INDEX idx_budget_ctg_reverse ON tBudgetCategories(ctg_id, budget_id);
GO

-- ======================================================================
-- 16. BẢNG GIAO DỊCH (TRUNG TÂM HỆ THỐNG)
-- ======================================================================
CREATE TABLE tTransactions (
    -- PRIMARY KEY
    id BIGINT PRIMARY KEY IDENTITY(1,1),
    
    -- FOREIGN KEYS
    acc_id INT NOT NULL,                         -- FK -> tAccounts (N-1)
    ctg_id INT NULL,                             -- FK -> tCategories (N-1) | NULL = Chi trừ nợ không phân loại
    wallet_id INT NULL,                          -- FK -> tWallets (N-1)
    event_id INT NULL,                           -- FK -> tEvents (N-1) | NULL = Không thuộc sự kiện
    debt_id INT NULL,                            -- FK -> tDebts (N-1) | NULL = Không liên quan nợ
    goal_id INT NULL,                            -- FK -> tSavingGoals (N-1) | NULL = Không liên quan mục tiêu
    ai_chat_id INT NULL,                         -- FK -> tAIConversations (N-1) | NULL = Nhập thủ công
    
    -- DATA COLUMNS
    amount DECIMAL(18,2) NOT NULL,               -- Số tiền giao dịch
    with_person NVARCHAR(100) NULL,              -- Tên người liên quan (VD: người vay, người trả)
    note NVARCHAR(500) NULL,                     -- Ghi chú (VD: "Ăn sáng", "Lương tháng 1")
    reportable BIT DEFAULT 1 NOT NULL,        -- 0: Không tính vào báo cáo | 1: Tính vào Dashboard
    source_type TINYINT DEFAULT 1 NOT NULL,      -- 1: manual | 2: chat | 3: voice | 4: receipt
    trans_date DATETIME DEFAULT GETDATE() NOT NULL,   -- Ngày giao dịch thực tế
    created_at DATETIME DEFAULT GETDATE() NOT NULL,   -- Ngày hệ thống ghi nhận
    deleted BIT DEFAULT 0 NOT NULL,           -- 0: Hoạt động | 1: Đã xóa (soft delete)
    
    -- CONSTRAINTS
    CONSTRAINT CHK_Transaction_Amount CHECK (amount > 0),
    CONSTRAINT CHK_Transaction_SourceType CHECK (source_type BETWEEN 1 AND 4),
    CONSTRAINT CHK_Transaction_Integrity CHECK (
        (source_type = 1 AND ai_chat_id IS NULL) OR          -- Manual thì không có chat_id
        (source_type IN (2,3,4) AND ai_chat_id IS NOT NULL)  -- AI thì bắt buộc có chat_id
    ),
    CONSTRAINT FK_Transactions_Account FOREIGN KEY (acc_id) REFERENCES tAccounts(id),
    CONSTRAINT FK_Transactions_Category FOREIGN KEY (ctg_id) REFERENCES tCategories(id),
    CONSTRAINT FK_Transactions_Wallet FOREIGN KEY (wallet_id) REFERENCES tWallets(id) ON DELETE CASCADE,
    CONSTRAINT FK_Transactions_Event FOREIGN KEY (event_id) REFERENCES tEvents(id),
    CONSTRAINT FK_Transactions_Debt FOREIGN KEY (debt_id) REFERENCES tDebts(id),
    CONSTRAINT FK_Transactions_Goal FOREIGN KEY (goal_id) REFERENCES tSavingGoals(id),
    CONSTRAINT FK_Transactions_Chat FOREIGN KEY (ai_chat_id) REFERENCES tAIConversations(id)
);
GO

-- Index: Tối ưu Báo cáo tài chính và Dashboard chính
CREATE INDEX idx_trans_main ON tTransactions(acc_id, wallet_id, deleted, trans_date DESC) 
INCLUDE (amount, ctg_id, reportable, source_type);

-- Index: Tối ưu query giao dịch theo Mục tiêu tiết kiệm
CREATE INDEX idx_trans_goal ON tTransactions(goal_id, deleted) 
INCLUDE (amount, trans_date) 
WHERE goal_id IS NOT NULL;

-- Index: Tối ưu query giao dịch theo Sự kiện
CREATE INDEX idx_trans_event ON tTransactions(event_id, deleted) 
INCLUDE (amount, trans_date, ctg_id) 
WHERE event_id IS NOT NULL;

-- Index: Tối ưu query giao dịch do AI tạo
CREATE INDEX idx_trans_ai ON tTransactions(ai_chat_id, deleted) 
INCLUDE (amount, trans_date, source_type) 
WHERE ai_chat_id IS NOT NULL;

-- Index: Tối ưu tính toán khoản nợ (Trả/Thu)
CREATE INDEX idx_trans_debt ON tTransactions(debt_id, deleted) 
INCLUDE (amount, trans_date) 
WHERE debt_id IS NOT NULL;

-- Index: Tối ưu query giao dịch theo Danh mục
CREATE INDEX idx_trans_category ON tTransactions(acc_id, ctg_id, deleted, trans_date DESC) 
INCLUDE (amount, wallet_id);
GO

-- DỮ LIỆU MẪU: Giao dịch
--INSERT INTO tTransactions (acc_id, ctg_id, wallet_id, amount, note) VALUES 
--GO

-- ======================================================================
-- 17. BẢNG THÔNG BÁO (1-N với tAccounts)
-- ======================================================================
CREATE TABLE tNotifications (
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),
    
    -- FOREIGN KEYS
    acc_id INT NOT NULL,                         -- FK -> tAccounts (N-1)     

	-- LOẠI THÔNG BÁO (Sử dụng TINYINT để tối ưu hiệu năng)
    -- 1: TRANSACTION (Giao dịch/Biến động số dư)
    -- 2: SAVING      (Mục tiêu tiết kiệm/Quỹ)
    -- 3: BUDGET      (Cảnh báo ngân sách/Vượt hạn mức)
    -- 4: SYSTEM      (Hệ thống/Cập nhật/Bảo mật)
    -- 5: CHAT_AI     (Thông báo từ trợ lý AI)
    -- 6: WALLETS     (Thông báo liên quan đến ví/số dư âm)
    -- 7: EVENTS      (Sự kiện/Lịch trình)
    -- 8: DEBT_LOAN   (Nhắc nợ/Thu nợ)
    -- 9: REMINDER    (Nhắc nhở chung/Daily nhắc ghi chép)
    notify_type TINYINT NOT NULL, 

    -- ID CỦA ĐỐI TƯỢNG LIÊN QUAN (Tùy theo notify_type)
    -- Ví dụ: Nếu type = 1 thì đây là ID của tTransactions
    -- Nếu type = 6 thì đây là ID của tWallets
    related_id BIGINT NULL,

	title NVARCHAR(100) NULL,                    -- Tiêu đề ngắn gọn (VD: "Cảnh báo ngân sách")
    content NVARCHAR(500) NOT NULL,              -- Nội dung chi tiết (VD: "Bạn đã xài hết 50% tiền Ăn uống")
    scheduled_time DATETIME DEFAULT GETDATE(),   -- Thời điểm thông báo (ngay hoặc hẹn lịch)
    notify_sent BIT DEFAULT 0,                       -- 0: Chưa gửi Push | 1: Đã gửi Push
    notify_read BIT DEFAULT 0,                       -- 0: Chưa đọc | 1: Đã đọc  
    created_at DATETIME DEFAULT GETDATE(),       -- Ngày tạo thông báo
	
    -- CONSTRAINTS
    CONSTRAINT CHK_Notify_Type CHECK (notify_type BETWEEN 1 AND 9),
    CONSTRAINT FK_Notifications_Account FOREIGN KEY (acc_id) REFERENCES tAccounts(id)
);
GO

-- Index: Tối ưu Worker quét thông báo cần gửi
CREATE INDEX idx_notify_worker ON tNotifications(scheduled_time, notify_sent) WHERE notify_sent = 0;

-- Index: Tối ưu load thông báo cho User UI
CREATE INDEX idx_notify_ui ON tNotifications(acc_id, notify_read, created_at DESC) INCLUDE (title, content, notify_type, related_id);

-- Index: Tối ưu load thông báo mới nhất
CREATE INDEX idx_notify_latest ON tNotifications(acc_id, created_at DESC) INCLUDE (notify_read, title, content);
GO

-- DỮ LIỆU MẪU: Thông báo
INSERT INTO tNotifications (acc_id, notify_type, title, content) VALUES 
(2, 3, N'Cảnh báo ngân sách', N'Bạn đã chi 80% ngân sách ăn uống');
GO

-- ======================================================================
-- 18. BẢNG GIAO DỊCH ĐỊNH KỲ/HÓA ĐƠN (1-N với tAccounts)
-- ======================================================================
CREATE TABLE tPlannedTransactions (
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),

    -- FOREIGN KEYS
    acc_id INT NOT NULL,    -- FK -> tAccounts (N-1)
    wallet_id INT NOT NULL, -- FK -> tWallets (N-1)
    
    -- Nếu người dùng tạo Bills menu sẽ chỉ hiện các danh mục chi, nếu là Recurring menu sẽ cho chọn tất cả loại giao dịch Thu/Chi/Vay-Nợ
    ctg_id INT NOT NULL,                         -- FK -> tCategories (N-1)
    currency_code VARCHAR(10) DEFAULT 'VND',     -- FK -> tCurrencies (N-1)
    
    -- DATA COLUMNS
    note NVARCHAR(500) NULL, -- Lưu tên hóa đơn hoặc ghi chú
    amount DECIMAL(18,2) NOT NULL, -- Số tiền mỗi kỳ
    
    -- Phân loại nghiệp vụ
    -- 1: Bill (Chi - Cần duyệt tay để tạo ra giao dịch)
    -- 2: Recurring (Thu/Chi/Nợ - Tự động hoàn toàn tạo giao dịch mà không cần duyệt tay)
    plan_type TINYINT NOT NULL,
    
    -- Phân loại giao dịch (Để biết khi sinh ra Transaction thì thuộc loại nào)
    -- 1: Khoản chi, 2: Khoản thu, 3: Cho vay, 4: Đi vay, 5: Thu nợ, 6: Trả nợ
    trans_type TINYINT NOT NULL,

    -- Cấu hình lặp lại
    repeat_type TINYINT NOT NULL,           --: 0: Không lặp lại, 1: Ngày, 2: Tuần, 3: Tháng, 4: Năm
    repeat_interval INT DEFAULT 1 NOT NULL, -- Mỗi "1" ngày, mỗi "2" tuần...   
    /* Giải thích Bitmask cho Dev: 
    - Nếu repeat_type = 2 (Tuần): CN=1, T2=2, T3=4, T4=8, T5=16, T6=32, T7=64.
    - Ví dụ: T2 + T4 = 10 (2 + 8). */
    repeat_on_day_val INT NULL,
    
    begin_date DATE NOT NULL,
    next_due_date DATE NOT NULL,                        -- Ngày đến hạn tiếp và backend có thể quét cột này để gửi thông báo.
    last_executed_at DATE NULL,                         -- Ngày thực hiện gần nhất (Để tránh duyệt trùng kỳ)
    end_date DATE NULL,                                 -- NULL nếu muốn lặp lại "Trọn đời".    

    active BIT DEFAULT 1 NOT NULL,                   -- 1: Đang chạy, 0: Tạm dừng      
    created_at DATETIME DEFAULT GETDATE() NOT NULL,     -- Ngày tạo ra để admin sắp xếp hiển thị theo ngày.

    -- CONSTRAINTS
    CONSTRAINT CHK_Plan_Amount    CHECK (amount > 0),                                   -- Chặn tiền âm hoặc bằng 0
    CONSTRAINT CHK_Plan_Repeat    CHECK (repeat_type BETWEEN 0 AND 4),                  -- Chỉ chấp nhận các mã lặp từ 0-4
    CONSTRAINT CHK_Plan_Interval  CHECK (repeat_interval >= 1),                         -- Khoảng cách lặp tối thiểu là 1
    CONSTRAINT CHK_Plan_Dates     CHECK (end_date IS NULL OR end_date >= begin_date),   -- Ngày kết thúc phải sau ngày bắt đầu
    CONSTRAINT CHK_Plan_Type      CHECK (plan_type IN (1, 2)),                          -- Chỉ cho phép loại Bill hoặc Recurring
    CONSTRAINT CHK_Plan_TransType CHECK (trans_type BETWEEN 1 AND 6),                   -- Phân loại giao dịch từ 1 đến 6
    CONSTRAINT CHK_Plan_NextDue   CHECK (next_due_date >= begin_date),                  -- Ngày đến hạn không được trước ngày bắt đầu
    
    CONSTRAINT FK_Bills_Acc FOREIGN KEY (acc_id) REFERENCES tAccounts(id),
    CONSTRAINT FK_Bills_Wallet FOREIGN KEY (wallet_id) REFERENCES tWallets(id) ON DELETE CASCADE,
    CONSTRAINT FK_Bills_Currency FOREIGN KEY (currency_code) REFERENCES tCurrencies(currency_code),
    CONSTRAINT FK_Bills_Category FOREIGN KEY (ctg_id) REFERENCES tCategories(id) ON DELETE CASCADE
);
GO

-- Index: Tối ưu Scheduler quét hóa đơn/giao dịch đến hạn
CREATE INDEX idx_planned_scan ON tPlannedTransactions(acc_id, next_due_date, active) INCLUDE (note, amount, plan_type, wallet_id);
GO