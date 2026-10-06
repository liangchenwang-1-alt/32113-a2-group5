# START HERE — 32113 Assignment 2 · Group 5 · CBA Customer 360

> 这份文件是给**组员和老师**看的入口说明（可以直接提交、可以贴给 tutor）。
> 内容：这个原型是什么、不装 Docker 怎么看结果、要自己跑一遍怎么做。

## 这是什么

按 A1 的选题（Commonwealth Bank 跨平台客户数据整合）做的 A2 **working prototype**：
3 个源系统 schema → 集成数据仓库 → 3 条数据用例报表，全部跑在**官方 Lab Environment**（Docker Compose）里。
数据是**确定性合成数据**，不含任何真实银行或客户数据。

| 官方要求（A2 brief p.4 (vi)） | 在哪 |
|---|---|
| a. ≥3 源系统 | `lab-env\advanced-database-lab\workspace\part3_warehouse_etl\01_source_ddl.sql` |
| b. ≥1 集成仓库 | `...\part3_warehouse_etl\02_warehouse_ddl.sql` |
| c. 合成数据 + 可直接执行的 SQL | `...\90_fixtures_sources.sql`、`02b_`、`03_`、`04_` |
| d. ≥3 报表/dashboard | `...\part5_reports_testing\10_report_views.sql`、`r1_r2_r3_reports.sql`、`dashboard.html` |
| e. 端到端测试 + 录屏 | `...\part5_reports_testing\测试矩阵.md`、录屏链接见报告 (vi)e 段 |

## 不装 Docker 也能看（任何电脑的浏览器）

| 想看什么 | 打开 |
|---|---|
| **报表 dashboard** | 下载 `lab-env\advanced-database-lab\workspace\part5_reports_testing\dashboard.html`，双击用浏览器打开 |
| **测试结果与对账** | `workspace\part5_reports_testing\测试矩阵.md`、`workspace\evidence\e2e_20261001_172851\SUMMARY.md` |
| **演示录屏** | 见报告 (vi)e 段的链接 |
| **报表口径** | `workspace\part5_reports_testing\报表规格.md` |

## 要自己跑一遍（需要 Docker Desktop，官方工作簿 §1.1.1）

```powershell
cd 命令
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-lab.ps1 start       # 起 5 个官方容器
powershell -NoProfile -ExecutionPolicy Bypass -File .\verify-e2e.ps1          # 建源→建仓→ETL→报表→测试
```

判定：`verify-e2e.ps1` 最后一行是 **`OVERALL: PASS`**（退出码 0）。
数据是确定性的：任何机器上跑出来，7 张表的行数与 md5 指纹都应完全相同（参考值见
`命令\export-sync-info.ps1` 的输出，或 `组员同步指南.md` §5）。

## 分工

| 成员 | 负责 |
|---|---|
| Md Mohsin Himel Mozumder | Architecture, integration and release coordination |
| Qiushi Huang | Source systems and synthetic data |
| Sejin Park | Warehouse and customer identity integration |
| Yutong Wang | Transaction and activity ETL; reconciliation |
| Liangchen Wang | Reports, end-to-end tests and demo coordination |

## 注意

- 不要提交 `lab-env\advanced-database-lab\data\`（容器数据卷，本机 805 MB），已在 `.gitignore` 里排除。
- 不要执行 `docker compose down -v`（会删数据）。
- 报告正文按课程要求由组员各自撰写，不在此仓库内。
