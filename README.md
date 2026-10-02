# VLSIT — AI-Assisted RTL Design & Verification Flow

**EN:** An AI-assisted RTL design and verification workflow based on engineering requirements and human review.

**VI:** Quy trình thiết kế và kiểm chứng RTL có hỗ trợ AI, dựa trên yêu cầu kỹ thuật và review của kỹ sư.

> **Status / Trạng thái:** Engineering prototype / Mẫu thử kỹ thuật · Claude Code prompts / Prompt Claude Code · Codex CLI skills / Skill Codex CLI · SystemVerilog RTL and verification / RTL SystemVerilog và verification

## Reference | Tài liệu tham khảo

[User guide / Hướng dẫn sử dụng — automatic and step-by-step / tự động và từng bước](GUIDELINE.md)

## Overview | Tổng quan

**EN:** VLSIT organizes work from hardware specification through requirements, configuration, RTL, assertions and testbench, verification, and documentation. Claude Code slash commands and Codex CLI skills guide the agent through the corresponding phases.

**VI:** VLSIT tổ chức quy trình từ đặc tả phần cứng, requirement, cấu hình, RTL, assertion và testbench, verification đến tài liệu. Slash command của Claude Code và skill của Codex CLI hướng dẫn agent thực hiện các phase tương ứng.

**EN:** The flow tracks requirements through RTL, SystemVerilog Assertions (SVA), test cases, and verification results using a Requirement Traceability Matrix (RTM).

**VI:** Flow truy vết requirement đến RTL, SystemVerilog Assertion (SVA), test case và kết quả verification bằng Requirement Traceability Matrix (RTM).

**EN:** The repository contains agent prompts, RTL rules, JSON Schemas, helper scripts, templates, diagrams, and saved design snapshots. The main sections describe the common flow; the design snapshots appear at the end.

**VI:** Repository chứa prompt cho agent, quy tắc RTL, JSON Schema, script hỗ trợ, template, sơ đồ và snapshot thiết kế. Các mục chính mô tả flow dùng chung; snapshot thiết kế được giới thiệu ở cuối README.

**EN — AI scope:** The project uses an LLM through Claude Code or Codex CLI. It does not contain model weights, a training or fine-tuning pipeline, a RAG system, or a standalone LLM API application. Model access and authentication are managed by the host environment.

**VI — Phạm vi AI:** Project dùng LLM thông qua Claude Code hoặc Codex CLI. Repository không chứa model weights, pipeline training/fine-tuning, hệ thống RAG hay ứng dụng LLM API độc lập. Môi trường chạy bên ngoài quản lý model và xác thực.

## Purpose | Mục đích

| EN | VI |
|---|---|
| Convert a hardware specification into identified requirements, a configuration, and an RTL design. | Chuyển đặc tả phần cứng thành requirement có định danh, cấu hình và thiết kế RTL. |
| Generate RTL, SVA, and testbench artifacts from a shared technical baseline. | Tạo artifact RTL, SVA và testbench theo cùng baseline kỹ thuật. |
| Compare AI-generated artifacts with lint, synthesis, and simulation results. | Đối chiếu artifact do AI tạo với kết quả lint, synthesis và simulation. |
| Track missing evidence, verification gaps, and review status. | Theo dõi bằng chứng còn thiếu, verification gap và trạng thái review. |
| Preserve design runs for inspection and comparison. | Lưu các lần chạy thiết kế để kiểm tra và so sánh. |

**EN:** The project supports AI-assisted RTL engineering and IP prototyping. Saved reports describe their recorded runs; they do not replace reproducible regression, formal proof, static timing analysis (STA), or ASIC sign-off.

**VI:** Project hỗ trợ nghiên cứu AI-assisted RTL engineering và tạo IP prototype. Report lưu trong repository chỉ mô tả lần chạy tương ứng; chúng không thay thế regression tái lập, formal proof, static timing analysis (STA) hoặc ASIC sign-off.

## Architecture & Flow | Kiến trúc và flow

~~~mermaid
flowchart TD
    U["Design description<br/>Mô tả thiết kế"] --> W[spec_writer]
    W --> S["Hardware specification<br/>Đặc tả phần cứng"]
    S --> P[spec_parser]
    P --> R[structured_spec.json]
    R --> G1{"Gate 1: Spec review<br/>Review đặc tả"}
    G1 --> C[config_ui]
    C --> F["final_config.json / Gate 2"]
    F --> RTL["rtl_generator: RTL + lint + synthesis"]
    F --> TB["tb_generator: testbench + test plan / Gate 4"]
    RTL --> A["sva_generator: assertions + bind + RTM"]
    A --> G3{"Gate 3b: Property review<br/>Review property"}
    G3 --> V["verification: compile + simulation + mutation"]
    TB --> V
    V --> G5{"Gate 5: Verification review<br/>Review verification"}
    G5 --> D["spec_pdf_generator: Markdown + PDF"]
~~~

### Architecture layers | Các lớp kiến trúc

| Layer / Lớp | Components / Thành phần | EN role | Vai trò |
|---|---|---|---|
| AI orchestration / Điều phối AI | .claude/commands/*.md, .agents/skills/*/SKILL.md | Guides Claude Code and Codex through phases, input checks, and review reports. | Hướng dẫn Claude Code và Codex qua các phase, kiểm tra đầu vào và báo cáo review. |
| Data and traceability / Dữ liệu và truy vết | JSON artifacts, JSON Schema, RTM | Stores requirements, configuration, mappings, and gate status. | Lưu requirement, cấu hình, mapping và trạng thái gate. |
| Design and execution / Thiết kế và thực thi | SystemVerilog, shell/Yosys scripts, EDA tools | Implements hardware and produces tool evidence. | Hiện thực phần cứng và tạo bằng chứng từ công cụ. |

**EN:** Slash commands and Codex skills are instructions for an agent, not shell programs or standalone workflow engines. Gate enforcement and artifact updates depend on the agent following those instructions; the repository has no unified orchestrator or validator that enforces the full flow. A phase reference such as /phase_name inside a Codex skill names a Claude source command; Codex reads and performs the matching skill directly.

**VI:** Slash command và Codex skill là hướng dẫn cho agent, không phải chương trình shell hay workflow engine độc lập. Việc thực thi gate và cập nhật artifact phụ thuộc vào agent làm đúng hướng dẫn; repository chưa có orchestrator hoặc validator thống nhất để cưỡng chế toàn bộ flow. Tham chiếu phase như /phase_name trong Codex skill là tên command Claude nguồn; Codex đọc và thực hiện skill tương ứng trực tiếp.

**EN:** RTL and testbench generation can proceed independently after configuration approval. In one session, /autoflow runs phases sequentially; the repository has no parallel scheduler.

**VI:** Có thể sinh RTL và testbench độc lập sau khi duyệt cấu hình. Trong một session, /autoflow chạy tuần tự; repository không có scheduler chạy song song.

## Repository structure | Cấu trúc repository

~~~text
VLSIT_RTL_Generator_AI_Model/
├── .claude/commands/         # Claude Code prompts / Prompt cho Claude Code
├── .agents/skills/           # Codex CLI skills / Skill cho Codex CLI
├── claude_template/          # Command templates and JSON Schemas / Mẫu command và JSON Schema
├── agent_structure/          # Flow diagrams / Sơ đồ flow
├── Result/                   # Saved design snapshots / Snapshot thiết kế
├── scripts/                  # Helper scripts / Script hỗ trợ
├── spec_template/            # IP, CSR, and RTL-rule templates / Mẫu spec IP, CSR và rule RTL
├── GUIDELINE.md              # Step-by-step user guide / Hướng dẫn từng bước
├── rtl_rule.md               # Project RTL rules / Rule RTL của project
├── vlsit_rtl_rule_default.md # Default ASIC RTL rules / Rule RTL ASIC mặc định
└── sourceme.sh               # Linux EDA environment setup / Thiết lập môi trường EDA Linux
~~~

**EN:** Each project subfolder has a short bilingual README describing its contents. Result folders hold only the artifacts present for that saved run. They are not a complete default output tree for a new design.

**VI:** Mỗi thư mục con của project có README song ngữ ngắn mô tả nội dung. Các thư mục trong Result chỉ chứa artifact đã lưu cho lần chạy đó; chúng không phải cây output mặc định đầy đủ cho thiết kế mới.

### Claude Code commands | Command Claude Code

| Command | EN purpose | Chức năng |
|---|---|---|
| /autoflow | Runs the gated flow across phases. | Điều phối flow qua các phase và gate review. |
| /spec_writer | Drafts an input specification from a design description. | Soạn đặc tả đầu vào từ mô tả thiết kế. |
| /spec_parser | Extracts requirements, IDs, ambiguity, and mappings. | Trích requirement, ID, ambiguity và mapping. |
| /config_ui | Selects parameters and checks configuration constraints. | Chọn parameter và kiểm tra ràng buộc cấu hình. |
| /rtl_generator | Generates RTL and runs lint and synthesis steps. | Sinh RTL và chạy lint, synthesis. |
| /sva_generator | Generates properties and bindings, and updates traceability. | Sinh property, bind và cập nhật traceability. |
| /tb_generator | Builds a SystemVerilog testbench and test plan. | Tạo testbench SystemVerilog và test plan. |
| /verification | Runs available verification and updates the reports. | Chạy verification khi có công cụ và cập nhật report. |
| /spec_pdf_generator | Builds specification documentation from design artifacts. | Tạo tài liệu đặc tả từ artifact thiết kế. |

**EN:** config_ui is an interactive command, not a separate GUI application. The testbench flow uses plain SystemVerilog, not UVM.

**VI:** config_ui là command tương tác, không phải ứng dụng GUI riêng. Flow testbench dùng SystemVerilog thuần, không dùng UVM.

### Codex CLI skills | Skill Codex CLI

**EN:** Invoke a project skill in Codex CLI with its skill name, and provide the specification or configuration path in the request when needed. Each skill maps to one Claude command.

**VI:** Gọi project skill trong Codex CLI bằng tên skill; khi cần, cung cấp đường dẫn spec hoặc cấu hình trong yêu cầu. Mỗi skill ánh xạ với một Claude command.

| Codex skill | Claude Code command |
|---|---|
| $source-command-autoflow | /autoflow |
| $source-command-spec-writer | /spec_writer |
| $source-command-spec-parser | /spec_parser |
| $source-command-config-ui | /config_ui |
| $source-command-rtl-generator | /rtl_generator |
| $source-command-sva-generator | /sva_generator |
| $source-command-tb-generator | /tb_generator |
| $source-command-verification | /verification |
| $source-command-spec-pdf-generator | /spec_pdf_generator |

**EN:** Skills preserve the source prompt's procedure and gates, and explain how to handle references to other phases. Some prompts and scripts assume a specific IP hierarchy or EDA setup; update module mappings, constraints, and tool paths before using them for another design.

**VI:** Skill giữ lại quy trình và gate từ prompt nguồn, đồng thời hướng dẫn xử lý tham chiếu đến phase khác. Một số prompt và script giả định hierarchy IP hoặc môi trường EDA cụ thể; cần cập nhật module mapping, constraint và đường dẫn công cụ trước khi dùng cho thiết kế khác.

### Gates & traceability | Gate và truy vết

The RTM links / RTM liên kết:

~~~text
REQ-ID → RTL block/file → Reviewed SVA → Selected TC → Execution result → Human sign-off
~~~

**EN:** In autoflow, the prompts require review at Gate 1 (specification), Gate 3b (properties), and Gate 5 (verification). Gate 2 and Gate 4 may be auto-approved when the orchestrator's stated conditions pass. Standalone commands can have different confirmation rules; establish the run mode before starting.

**VI:** Trong autoflow, prompt yêu cầu review tại Gate 1 (specification), Gate 3b (property) và Gate 5 (verification). Gate 2 và Gate 4 có thể được tự xác nhận nếu đạt điều kiện của orchestrator. Command chạy riêng có thể có quy tắc xác nhận khác; cần thống nhất chế độ trước khi chạy.

**EN:** The verification prompt calculates eligibility from RTL/SVA/TC traceability, simulation, and a mutation score of at least 85%, or N/A under the current policy. N/A is not evidence that mutation requirements passed. Gate 5 approval can still leave requirements blocked or unsigned.

**VI:** Prompt verification tính eligibility từ traceability RTL/SVA/TC, simulation và mutation score tối thiểu 85%, hoặc N/A theo chính sách hiện tại. N/A không chứng minh mutation đã đạt. Dù Gate 5 được duyệt, vẫn có thể còn requirement bị khóa hoặc chưa sign-off.

## Requirements | Môi trường cần có

| Tool/environment / Công cụ/môi trường | EN purpose | Mục đích |
|---|---|---|
| Claude Code or Codex CLI | Reads and performs command prompts or project skills. | Đọc và thực hiện command prompt hoặc project skill. |
| Linux, Bash, Environment Modules | Runtime assumed by the current scripts. | Môi trường mà các script hiện tại giả định. |
| Verilator | RTL lint. | Lint RTL. |
| Yosys; slang plugin when required by the SystemVerilog frontend | Synthesis and support for mutation workflow. | Synthesis và hỗ trợ mutation workflow. |
| GF180MCU Liberty libraries | Technology mapping at TT/SS corners. | Technology mapping tại các corner TT/SS. |
| Synopsys VCS or another available simulator | Compile and simulation with SVA in the original flow; separate installation and license required. | Compile và simulation có SVA trong flow gốc; cần cài đặt và license riêng. |
| Icarus Verilog | Alternative simulation in some runs; the current Icarus path skips SVA. | Simulation thay thế ở một số flow; đường chạy Icarus hiện bỏ qua SVA. |
| Python 3 and Matplotlib | Runs the included PDF conversion script. | Chạy script chuyển PDF đi kèm. |

**EN:** Artifacts record Verilator 5.041, Yosys 0.58/0.58+35, VCS, and Icarus 13.0. These are observed environment versions, not a tested compatibility matrix. sourceme.sh also loads a toolchain and lists tools from OSS CAD Suite; adapt it for the target IP. SymbiYosys or cocotb in the setup does not mean the repository contains a complete formal or cocotb flow.

**VI:** Artifact ghi nhận Verilator 5.041, Yosys 0.58/0.58+35, VCS và Icarus 13.0. Đây là phiên bản đã xuất hiện trong môi trường chạy, không phải compatibility matrix đã kiểm thử. sourceme.sh còn nạp toolchain và liệt kê công cụ từ OSS CAD Suite; cần điều chỉnh theo IP đích. Việc setup có SymbiYosys hoặc cocotb không đồng nghĩa repository có flow formal hoặc cocotb hoàn chỉnh.

## Usage | Cách sử dụng

### 1. Prepare the environment | Chuẩn bị môi trường

~~~bash
git clone https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model.git
cd VLSIT_RTL_Generator_AI_Model
~~~

**EN:** Review and adapt sourceme.sh before sourcing it. The script assumes /etc/profile.d/modules.sh, configured EDA/toolchain modules, and a PDK under /tools/PDK. It does not install tools and does not load VCS in the current version.

**VI:** Kiểm tra và điều chỉnh sourceme.sh trước khi source. Script giả định có /etc/profile.d/modules.sh, các module EDA/toolchain và PDK dưới /tools/PDK. Script không cài công cụ và phiên bản hiện tại không nạp VCS.

~~~bash
source sourceme.sh
~~~

**EN:** On Windows, use a Linux environment such as WSL or an EDA server, then adapt paths and tool setup. The shell scripts are not designed for direct PowerShell execution.

**VI:** Trên Windows, dùng môi trường Linux như WSL hoặc máy chủ EDA, sau đó điều chỉnh đường dẫn và cách nạp công cụ. Shell script không được thiết kế để chạy trực tiếp bằng PowerShell.

### 2. Prepare a project and specification | Chuẩn bị project và spec

1. **EN:** Work on a separate branch or copy to preserve reference snapshots.  
   **VI:** Làm việc trên branch hoặc bản sao riêng để giữ nguyên snapshot tham khảo.
2. **EN:** Put the design specification at spec/<ip_name>_spec.md. Define interfaces, parameters, reset, functionality, timing, and error behavior.  
   **VI:** Đặt đặc tả tại spec/<ip_name>_spec.md. Mô tả interface, parameter, reset, chức năng, timing và error behavior.
3. **EN:** Adapt prompts for the target IP, including parser mappings, configuration constraints, module hierarchy, SVA, test plan, and document structure. Update related templates together.  
   **VI:** Điều chỉnh prompt theo IP đích, gồm parser mapping, ràng buộc cấu hình, hierarchy module, SVA, test plan và bố cục tài liệu. Cập nhật đồng bộ các template liên quan.
4. **EN:** Place JSON Schemas where the prompts expect them; source templates are in claude_template/schemas/.  
   **VI:** Đặt JSON Schema tại đường dẫn mà prompt yêu cầu; schema mẫu nằm trong claude_template/schemas/.

**EN:** Some snapshots contain input artifacts with names that overlap Claude command prompts. Check each file's role and source before using it as a baseline.

**VI:** Một số snapshot có artifact đầu vào trùng tên với prompt Claude command. Xác định vai trò và nguồn gốc của file trước khi dùng làm baseline.

### 3. Run in Claude Code | Chạy trong Claude Code

**EN:** Open Claude Code at the project root and enter slash commands in the conversation, not in a shell terminal.

**VI:** Mở Claude Code tại project root và nhập slash command trong hội thoại, không nhập trong terminal shell.

~~~text
/autoflow spec/<ip_name>_spec.md
~~~

**EN:** To draft a specification from an initial description:

**VI:** Để soạn spec từ mô tả ban đầu:

~~~text
/autoflow --describe
~~~

**EN:** Or run phases individually for detailed review:

**VI:** Hoặc chạy từng phase để review chi tiết:

~~~text
/spec_parser spec/<ip_name>_spec.md
/config_ui
/rtl_generator
/tb_generator
/sva_generator
/verification
/spec_pdf_generator
~~~

**EN:** Review requirements before Gate 1, property meaning and vacuity before Gate 3b, and execution logs and verification gaps before Gate 5. Generation commands may create or update files in the working project.

**VI:** Review requirement trước Gate 1, ý nghĩa/vacuity của property trước Gate 3b, và log thực thi cùng verification gap trước Gate 5. Lệnh generation có thể tạo hoặc cập nhật file trong project làm việc.

### 4. Run in Codex CLI | Chạy trong Codex CLI

**EN:** Open Codex CLI at the project root and call the matching skill in the conversation. For example:

**VI:** Mở Codex CLI tại project root và gọi skill tương ứng trong hội thoại. Ví dụ:

~~~text
$source-command-autoflow
Use spec/<ip_name>_spec.md
~~~

**EN:** Call an individual phase with its mapped skill. References such as /autoflow or /phase_name inside a skill refer to the source Claude prompt; they are not terminal commands.

**VI:** Gọi phase riêng bằng skill đã ánh xạ. Tham chiếu như /autoflow hoặc /phase_name bên trong skill là prompt Claude nguồn, không phải lệnh terminal.

### 5. Resume an interrupted flow | Tiếp tục flow bị gián đoạn

~~~text
/autoflow spec/<ip_name>_spec.md --from phase3b
/autoflow spec/<ip_name>_spec.md --from phase5
/autoflow spec/<ip_name>_spec.md --from phase6
~~~

**EN:** Resume uses saved artifacts. Before continuing, confirm that the specification, configuration, RTL, and reports use the same baseline. Editing an input artifact can invalidate downstream results.

**VI:** Resume sử dụng artifact đã lưu. Trước khi tiếp tục, xác nhận spec, cấu hình, RTL và report thuộc cùng một baseline. Sửa artifact đầu vào có thể làm mất hiệu lực kết quả phía sau.

## Current limitations | Hạn chế hiện tại

- **Template drift — EN:** Active commands and templates are not fully aligned; the verification versions differ. Some older synthesis examples do not reflect fixes in later snapshots.  
  **VI:** Command đang dùng và template chưa hoàn toàn đồng nhất; bản verification có khác biệt. Một số ví dụ synthesis cũ chưa phản ánh các sửa lỗi trong snapshot mới hơn.
- **Schema drift — EN:** Some JSON artifacts omit fields or use formats that differ from the sample schemas; there is no unified automated validation.  
  **VI:** Một số JSON artifact thiếu trường hoặc khác định dạng schema mẫu; chưa có validation tự động thống nhất.
- **Evidence completeness — EN:** Some final logs, mutation wrappers, and working artifacts are not packaged, so snapshots alone may not reproduce every result.  
  **VI:** Một số log cuối, mutation wrapper và artifact làm việc không được đóng gói; chỉ từ snapshot có thể không tái lập được mọi kết quả.
- **Verification scope — EN:** Pass counts, property counts, and gate approval do not prove full requirement coverage. Some test cases report information or check default configuration only.  
  **VI:** Số lượng pass, property hay gate đã duyệt không chứng minh bao phủ đủ requirement. Một số test case chỉ cung cấp thông tin hoặc kiểm tra cấu hình mặc định.
- **Physical implementation — EN:** Synthesis and cell mapping do not establish timing closure. The repository has no complete STA, place-and-route, CDC/RDC, or sign-off flow.  
  **VI:** Synthesis và cell mapping không xác nhận timing closure. Repository chưa có flow STA, place-and-route, CDC/RDC hoặc sign-off hoàn chỉnh.
- **Documentation — EN:** PDFs summarize artifacts; resolve conflicts by checking source files and logs. The Matplotlib PDF script has layout limits, including clipping long table cells.  
  **VI:** PDF tổng hợp artifact; khi có mâu thuẫn, đối chiếu source và log. Script PDF dùng Matplotlib có giới hạn trình bày, gồm khả năng cắt nội dung cell bảng dài.

## Further reading | Đọc thêm

- [Manual workflow / Flow từng bước](GUIDELINE.md)
- [Automatic workflow prompt / Prompt autoflow](.claude/commands/autoflow.md)
- [RTL coding rules / Quy tắc RTL](rtl_rule.md)
- [Spec parser authoring rules / Quy tắc biên soạn spec parser](claude_template/spec_parser_authoring_rules.md)
- [Active Claude Code commands / Claude Code command đang dùng](.claude/commands/)
- [Codex CLI project skills / Skill Codex CLI](.agents/skills/)
- [JSON Schema templates / JSON Schema mẫu](claude_template/schemas/)
- [Saved design runs / Snapshot thiết kế](Result/)
- [Architecture diagrams / Sơ đồ kiến trúc](agent_structure/)

## License | Giấy phép

**EN:** The analyzed snapshot has no LICENSE file. Confirm use and distribution terms with the repository owner. External EDA tools and PDKs have separate licenses.

**VI:** Snapshot đã rà soát không có file LICENSE. Xác nhận điều kiện sử dụng và phân phối với chủ repository. Công cụ EDA và PDK bên ngoài áp dụng license riêng.

## Reference design examples | Ví dụ thiết kế tham khảo

**EN:** These snapshots show how the flow was applied to two design types. They help explain the saved artifacts and evidence limits. Their metrics describe individual runs and do not guarantee results for other designs.

**VI:** Các snapshot minh họa cách áp dụng flow cho hai loại thiết kế. Chúng giúp giải thích artifact đã lưu và giới hạn bằng chứng. Số liệu phản ánh từng lần chạy, không đảm bảo kết quả cho thiết kế khác.

| Snapshot | Saved artifacts / Artifact đã lưu | Evidence limits / Giới hạn bằng chứng |
|---|---|---|
| RISCV_23_08_2026 | EN: RV32IM processor core; 18 RTL files (17 modules and 1 package); 191 requirements; 181 property records; GF180 synthesis artifacts.<br/>VI: RV32IM processor core; 18 file RTL (17 module và 1 package); 191 requirement; 181 property record; artifact synthesis GF180. | EN: Stops at Gate 3; 0 requirements signed off. The RTM records 83 vacuous properties in the smoke test.<br/>VI: Dừng ở Gate 3; 0 requirement được sign-off. RTM ghi nhận 83 property vacuous trong smoke test. |
| RISCV_24_08_2026 | EN: RV32IM processor core; 35 assertion records; report states 24/24 test cases passed and 8/23 requirements signed off.<br/>VI: RV32IM processor core; 35 assertion record; report ghi 24/24 test case pass và 8/23 requirement sign-off. | EN: The packaged simulation log is an older failed run. The final passing log referenced by the report is absent from the snapshot.<br/>VI: Log simulation được đóng gói là lần chạy cũ bị fail. Log pass cuối mà report tham chiếu không có trong snapshot. |
| DOWNSCALER_03_09_2026 | EN: AXI4-Stream data-width downscaler; 4 RTL modules; default 64-bit to 32-bit; report states 11 test cases passed and 1 N/A, with 12/16 requirements signed off.<br/>VI: AXI4-Stream data-width downscaler; 4 module RTL; mặc định 64-bit xuống 32-bit; report ghi 11 test case pass, 1 N/A và 12/16 requirement sign-off. | EN: Timing has not been checked by STA. Width ratios outside the default configuration need their own regression.<br/>VI: Timing chưa được kiểm tra bằng STA. Tỷ lệ width ngoài cấu hình mặc định cần regression riêng. |

### RV32IM processor core | Lõi xử lý RV32IM

**EN:** The core snapshot shows an IF → ID → EX → MEM → WB pipeline with a register file, hazard/forwarding control, CSR, and trap control. EX contains the ALU, branch unit, and multiply/divide units; MEM uses an LSU. WB writes back to the register file and has no separate WB module. The I-bus and D-bus use a custom valid/ready protocol.

**VI:** Snapshot core thể hiện pipeline IF → ID → EX → MEM → WB cùng register file, hazard/forwarding control, CSR và trap control. EX gồm ALU, branch unit và multiply/divide; MEM dùng LSU. WB ghi dữ liệu về register file, không có module WB riêng. I-bus và D-bus dùng giao thức valid/ready tùy chỉnh.

**EN:** The two RISC-V folders are independent snapshots, not sequential revisions: the 23 Aug snapshot uses spec revision 0.4, while the 24 Aug snapshot uses revision 0.2. Update absolute paths in file lists and compile scripts before running elsewhere. Compiling a testbench alone is not complete verification with SVA and mutation.

**VI:** Hai thư mục RISC-V là snapshot độc lập, không phải các revision nối tiếp: snapshot 23 Aug dùng spec revision 0.4, snapshot 24 Aug dùng revision 0.2. Cập nhật đường dẫn tuyệt đối trong file list và compile script trước khi chạy ở máy khác. Chỉ compile testbench không phải verification đầy đủ có SVA và mutation.

### AXI4-Stream data-width downscaler | Bộ giảm độ rộng dữ liệu AXI4-Stream

**EN:** The downscaler snapshot uses the path S_AXIS → width_split → FIFO → m_axis_if → M_AXIS. It splits beats in LSB-first order, forwards TKEEP per slice, and forwards TLAST on the last slice. It converts AXI4-Stream data width; it does not downscale image resolution.

**VI:** Snapshot downscaler dùng luồng S_AXIS → width_split → FIFO → m_axis_if → M_AXIS. Thiết kế chia beat theo thứ tự LSB-first, truyền TKEEP theo từng slice và truyền TLAST ở slice cuối. Đây là bộ chuyển đổi độ rộng dữ liệu AXI4-Stream, không giảm độ phân giải ảnh.

**EN:** To run the default configuration with Icarus from the repository root:

**VI:** Để chạy cấu hình mặc định bằng Icarus từ repository root:

~~~bash
cd Result/DOWNSCALER_03_09_2026
bash src/tb/run_icarus_sim.sh
~~~

**EN:** The script compiles and simulates into sim/, but does not run SVA. A timing test case marked N/A still increments the snapshot testbench's pass counter; inspect each test result instead of relying only on the PASS total.

**VI:** Script compile và simulate vào sim/, nhưng không chạy SVA. Test timing đánh dấu N/A vẫn làm tăng bộ đếm pass trong testbench snapshot; cần xem kết quả từng test thay vì chỉ dựa vào tổng PASS.
