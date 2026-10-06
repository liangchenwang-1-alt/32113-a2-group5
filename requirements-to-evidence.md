# 要求 → 证据 映射（requirements-to-evidence）

> 每条官方要求 → 由什么证据证明已完成 → 谁产出 → 当前状态。
> 证据必须**可复现**：内部计划原文要求 "No module is 'done' solely because it runs on its author's machine."
> 状态：`[ ]` 无 / `[~]` 部分 / `[x]` 有 / `[!]` 阻塞

## 一、报告（A2 brief pp.3–4）

| 要求 | 证据形式 | 状态 | 备注 |
|---|---|---|---|
| Executive Summary 100–250 字 | 报告 §Executive Summary；Canvas 显示字数 | [ ] | 结果产出后全组共同写 |
| Introduction 300–400 字 | 报告 §Introduction | [ ] | 与 A1 模板的 500–750 字不同，以 A2 brief 为准 |
| Solution Architecture | 架构图（源系统→staging→ETL→仓库→报表）+ 图内标注数据流向 | [ ] | 内部计划要求"箭头表示真实数据移动" |
| Conceptual Model of Data Entities | 概念模型图（实体+关系，不含物理细节） | [ ] | |
| Logical Data Model of Data Entities | 逻辑模型（表、键、类型、粒度、null 规则） | [ ] | 需与最终 SQL 的 DDL 完全一致 |
| Design Rationale | 报告文字：use case fit / performance / complexity / cost | [ ] | brief p.4 原文拼作 "Design Rational"，按 Rationale 写 |
| Design Trade-offs | 报告文字：取舍与被放弃的方案及原因 | [ ] | |
| Conclusion 200–300 字 | 报告 §Conclusion | [ ] | |
| References（Harvard） | 报告 §References | [ ] | 引用需逐篇核对作者/年份/出处 |
| 报告整体质量（结构/语法/清晰） | 定稿 PDF + Turnitin 报告 | [ ] | 占 12.5% |

## 二、原型（A2 brief p.4，占 50%）

| 要求 | 证据形式 | 状态 | 备注 |
|---|---|---|---|
| ≥3 源系统数据库与 schema | 源库 DDL 脚本 + 执行结果（表清单/行数） | [x] | `part3_warehouse_etl\01_source_ddl.sql`（s1_core / s2_payments / s3_digital）→ `evidence\e2e_20261001_172851\01_source_ddl.txt` |
| ≥1 集成仓库数据库与 schema | 仓库 DDL 脚本 + 执行结果 | [x] | `02_warehouse_ddl.sql`：4 维 + 3 事实 + xref + 2 审计表 → `02_warehouse_ddl.txt` |
| 合成数据 | 数据生成/插入脚本（**确定性**：固定种子或字面 INSERT，便于复现） | [x] | `90_fixtures_sources.sql`：全部字面 INSERT、无 `random()`；S1 5+5 / S2 5+8 / S3 4+6+4 |
| 建库/schema 的 SQL | `.sql` 文件，带注释 | [x] | 同上两个文件 |
| 抽取 SQL（源→staging） | `.sql` 文件，带注释 | [x] | 抽取逻辑写在 `04_etl_load_facts.sql` 里（从源 schema 直接 select 到 `dw.*`，未单独建 staging 表 → 报告里说明取舍） |
| 转换/装载 SQL（→仓库） | `.sql` 文件，带注释 | [x] | `02b_dimensions.sql` / `03_identity_xref.sql` / `04_etl_load_facts.sql` |
| **完全注释、可直接执行无错** | 在干净库上重跑：退出码 0，无手工修补 | [x] | 两遍全流程 19 步全 exit=0；`verify-e2e.ps1` 退出码 0 → `SUMMARY.md` |
| **明确映射到设计组件** | 脚本头注释标注对应设计组件 | [x] | 每个 `.sql` 头部有 design mapping 注释 |
| ≥3 报表/dashboard | 报表视图 SQL + 截图/导出结果 | [x] | R1/R2/R3 + 支撑视图 R4–R6 + `dashboard.html`；口径 `报表规格.md`；输出 `09_reports.txt` |
| 端到端测试 | 测试矩阵：用例 → 预期 → 实际 → 通过/失败 | [x] | `测试矩阵.md` T1–T13（T1–T7、T9–T13 PASS）；**9 个真实缺陷**记录 |
| 录屏链接 | 报告内可点击链接；**用无所有者权限的账号验证可访问** | [~] | **唯一缺口**：需本人真实录制 → `演示口播稿.md`（含验证记录表） |
| 在官方 Lab Environment 运行 | `docker ps` 5 个容器 Running + `run-lab.ps1 smoke` 全 PASS | [x] | 5 容器 Up；官方 §1.2 冒烟 7/7 PASS |

## 三、团队与合规（A2 brief pp.3–5）

| 要求 | 证据形式 | 状态 | 备注 |
|---|---|---|---|
| 个人贡献证据（logbook） | 附录：每人 日期/任务/产物版本/结果 | [~] | 模板 Table 3：Student Name / Allocated Task / Report Section / Completion Date；我这份已起草 `个人贡献证据_Member5.md`（含 AI 协助标注），小时数待本人填 |
| 沟通证据 | 邮件/Teams 记录、时间戳交付、截图、反馈与改进证据 | [ ] | |
| Contribution Form（0–100%） | 官方模板填写 | [ ] | 注意：这是**个人表现评分**，不是五份加起来 = 100% |
| 自我评估（HD/D/C/P/F） | 报告内声明 | [ ] | brief p.3 允许全组自评 |
| ≥3 份**教师签字** meeting minutes | 扫描/原件附在附录 | [ ] | 现有 1 份（Week2.docx, Meeting 1, Saba 13/8/26 已签）；签字不能补造，必须老师本人签 |
| 每次会议都有 minutes | 其余会议记录 | [ ] | |
| GenAI 使用合规 | 按学科页要求：如实声明 + 聊天记录 + 250 字理由与反思 + 截图 | [ ] | **报告本身不得由 GenAI 生成**（A2 p.5） |
| Harvard 引用规范 | 全部来源标注 | [ ] | |
| 每组仅 1 人提交 | 提交回执 | [ ] | A1 由 Yutong Wang 25398405 提交 |

## 四、Presentation（A2 brief p.4）

| 要求 | 证据形式 | 状态 |
|---|---|---|
| 每人参与 | 演示分工表 + 现场/录制 | [~] 流程表已排 `演示与展示协调.md`；**分工两套说法未定**（已问组里） |
| 约 10 分钟（≤15） | 排练计时记录 | [~] 按 10 分钟排、留 5 分钟余量；计时待填 |
| 约 10 分钟 Q&A | — | [~] Q&A 常见问题 8 条 + 答案要点已备 |
| 每人能回答整份项目的问题 | 交叉演练记录（互相讲非自己模块） | [~] 我这段已备；全组交叉演练待做 |

## 五、这份映射本身怎么用

1. 组内对齐：先把 B1（环境）和 B5（分工）确认掉，上表的 Owner 才能填实。
2. 每组交付前：逐行改成 `[x]` 前先有证据文件路径。
3. 提交前：`CHECKLIST.md` 的 F 段疑点逐条有 tutor 的答复记录。
