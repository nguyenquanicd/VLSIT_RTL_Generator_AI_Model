# spec_template

**English | Tiếng Việt**

## 1. Purpose | Mục đích

**EN:** This folder holds the three source documents used to specify and implement an ASIC IP in the VLSIT flow: the design specification template, the CSR specification template, and the RTL design rules.

**VI:** Thư mục này chứa ba tài liệu gốc dùng để đặc tả và hiện thực một ASIC IP trong flow VLSIT: mẫu design specification, mẫu đặc tả CSR, và bộ quy tắc thiết kế RTL.

## 2. Files | Các file

| File | EN | VI |
|---|---|---|
| [VLSIT_ASIC_IP_Design_Specification_Template.md](VLSIT_ASIC_IP_Design_Specification_Template.md) | Template for the IP design specification (22 sections: requirements, architecture, interfaces, clock/reset, parameters, behavior, RTL contract, verification, DFT, physical design, traceability). | Mẫu design specification của IP (22 mục: yêu cầu, kiến trúc, giao diện, clock/reset, tham số, hành vi, ràng buộc RTL, kiểm chứng, DFT, physical design, truy vết). |
| [VLSIT_CSR_Specification_Template.xlsx](VLSIT_CSR_Specification_Template.xlsx) | Workbook that defines all CSRs (control and status registers). It is the only place where registers are specified. | Workbook định nghĩa toàn bộ CSR (thanh ghi điều khiển và trạng thái). Đây là nơi duy nhất đặc tả thanh ghi. |
| [VLSIT_RTL_Design_Rule.md](VLSIT_RTL_Design_Rule.md) | Mandatory RTL coding rules for ASIC synthesis and tapeout: naming, file structure, reset, CDC, prohibited constructs, readiness checklist. | Quy tắc viết RTL bắt buộc cho ASIC synthesis và tapeout: đặt tên, cấu trúc file, reset, CDC, các cấu trúc bị cấm, checklist sẵn sàng tapeout. |

## 3. How the files work together | Cách các file phối hợp

```text
VLSIT_ASIC_IP_Design_Specification_Template.md  (copy and fill in per IP)
   ├── Section 11 ──► VLSIT_CSR_Specification_Template.xlsx   (registers, fields, resets)
   └── Section 14 ──► VLSIT_RTL_Design_Rule.md                (RTL coding authority)
```

**EN:**
1. Copy the specification template and replace every `<placeholder>`. Mark inapplicable sections N/A with a reason.
2. Copy the CSR workbook and fill one sheet per register map. Do not repeat registers in the specification; refer to the workbook.
3. Write RTL that complies with the RTL design rules. The specification must not add local RTL exceptions.

**VI:**
1. Sao chép mẫu specification và thay mọi `<placeholder>`. Mục không áp dụng ghi N/A kèm lý do.
2. Sao chép workbook CSR và điền mỗi register map vào một sheet. Không nhắc lại thanh ghi trong specification, chỉ tham chiếu workbook.
3. Viết RTL tuân theo bộ quy tắc RTL. Specification không được thêm ngoại lệ RTL cục bộ.

## 4. CSR workbook layout | Cấu trúc workbook CSR

| Sheet | EN | VI |
|---|---|---|
| `CSR` | Register map, single clock (`Asynchronous=0`). | Register map một clock (`Asynchronous=0`). |
| `ASYNC_CSR` | Same format, bus and register clocks are asynchronous (`Asynchronous=1`). | Cùng format, clock bus và clock thanh ghi bất đồng bộ (`Asynchronous=1`). |
| `Register_Description` | Documentation only: bit types and their circuits. | Chỉ là tài liệu: các loại bit và mạch tương ứng. |

Each register-map sheet has two tables | Mỗi sheet register map có hai bảng:

- **`Table - Configuration`:** `Module Name`, `Protocol` (APB), `Data Width` (32), `Address Width` (16), `Write Strobe` (4), `Asynchronous` (0/1).
- **`Table - Register Definition`:** columns `REGISTER | OFFSET | BIT NAME | FIELD WIDTH | BIT TYPE | RESET VALUE | DESCRIPTION`. A register row (name, offset, reset) is followed by one row per field (name, bit range such as `[31]` or `[28:27]`, type, reset, description). | Một hàng thanh ghi (tên, offset, reset) theo sau là mỗi hàng một field (tên, dải bit như `[31]` hoặc `[28:27]`, loại, reset, mô tả).

| Bit type | EN | VI |
|---|---|---|
| `rw` | Software read/write. | Phần mềm đọc/ghi. |
| `ro` | Read-only, driven by hardware. | Chỉ đọc, do phần cứng điều khiển. |
| `rwi` | Software read/write; hardware can also write. Software write has priority. | Phần mềm đọc/ghi; phần cứng cũng có thể ghi. Ghi từ phần mềm ưu tiên hơn. |
| `w1c` | Write 1 to clear; hardware can set. | Ghi 1 để xóa; phần cứng có thể set. |

A field named `reserved` has no port, reads as 0, and ignores writes. | Field tên `reserved` không có port, đọc ra 0 và bỏ qua lệnh ghi.

## 5. RTL design rules at a glance | Tóm tắt quy tắc RTL

**EN:** Each rule has a stable ID (for example `NAM-07`, `ENM-05`, `P15`). Prohibited constructs are listed only in Section 10 of the rule file. Examples of key rules: names are at most 30 characters; only `space` indentation; comment lines are at most 100 characters; FSM states are enums named `ENUM_ST_<FUNCTION>`; DFT ports use `i_dft_*` / `o_dft_*`.

**VI:** Mỗi rule có ID cố định (ví dụ `NAM-07`, `ENM-05`, `P15`). Các cấu trúc bị cấm chỉ liệt kê ở Section 10 của file rule. Một số rule chính: tên không quá 30 ký tự; chỉ thụt lề bằng `space`; dòng comment không quá 100 ký tự; state FSM là enum đặt tên `ENUM_ST_<FUNCTION>`; port DFT dùng `i_dft_*` / `o_dft_*`.

## 6. Related tool | Công cụ liên quan

**EN:** The CSR RTL is generated from the workbook by the separate `APB-CSR-Generator` repository (`CSR_Generation.py <workbook.xlsx> <sheet_name>`). Check its generated RTL against the RTL design rules before use.

**VI:** RTL của CSR được sinh từ workbook bằng repo riêng `APB-CSR-Generator` (`CSR_Generation.py <workbook.xlsx> <sheet_name>`). Cần kiểm tra RTL sinh ra theo bộ quy tắc RTL trước khi dùng.

## 7. Editing rules | Quy ước khi sửa

**EN:** Before adding a rule to `VLSIT_RTL_Design_Rule.md`, check it against the existing rules for duplicates and conflicts, and record the decision.

**VI:** Trước khi thêm rule vào `VLSIT_RTL_Design_Rule.md`, kiểm tra trùng lặp và xung đột với các rule hiện có, và ghi lại quyết định.
