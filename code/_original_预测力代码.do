* ==================================================
* 研究主题：ESG对企业负面新闻的影响（DID模型 + 稳健性 + 异质性）
* ==================================================

* 1. 导入Excel数据
import excel "/Users/Jinzichang/Desktop/维度二数据.xls", firstrow clear

* 2. 1%—99%缩尾处理（消除极端值）
local vars esg zsz pd jgcg ZCFZL ROE NHSYL GDQYHJ
winsor2 `vars', cuts(1 99) replace

* 3. 删除核心变量缺失值
drop if missing(esg, ROE, ZCFZL)

* 4. 生成面板数据专用id + 控制变量
encode 证券代码, gen(firm_id)  // 证券代码转数字ID
gen ln_size = ln(zsz)          // 企业规模（总市值对数）
gen Treat = p                  // 处理组标识（p=1为实验组）

* 5. 设定面板结构
sort firm_id year
tsset firm_id year

* 6. 构造DID政策时点（首次处理年份）
bysort firm_id (year): gen first_treat_year = year if p == 1 & L.p == 0
bysort firm_id (year): replace first_treat_year = first_treat_year[_n-1] if missing(first_treat_year)
gen Post = (year >= first_treat_year) & !missing(first_treat_year)  // 政策后=1

* 7. 生成交互项（DID核心）
gen ESG_Treat      = esg * Treat
gen ESG_Post       = esg * Post
gen Treat_Post     = Treat * Post
gen ESG_Treat_Post = esg * Treat * Post

* 8. 被解释变量：负面新闻（滞后1/2期）
rename fm 负面新闻数
gen 负面新闻数_t1 = L.负面新闻数   // 滞后1期（核心被解释变量）
gen 负面新闻数_t2 = L2.负面新闻数  // 滞后2期（稳健性用）

* 9. 再次缩尾 + 剔除缺失
local wvars 负面新闻数_t1 负面新闻数_t2 esg Treat Post ln_size ZCFZL ROE jgcg
winsor2 `wvars', cuts(1 99) replace
drop if missing(负面新闻数_t1, 负面新闻数_t2, esg, Treat, Post)

* 10. 基准回归（OLS）
gen ln_负面新闻数_t1 = ln(负面新闻数_t1 + 1)
reg ln_负面新闻数_t1 esg ln_size ZCFZL ROE jgcg i.firm_id i.year, vce(cluster firm_id)
est store 基准回归

* 11. 核心DID回归（OLS + 负二项 + 泊松）
reg ln_负面新闻数_t1 esg Treat Post ESG_Treat ESG_Post Treat_Post ESG_Treat_Post ln_size ZCFZL ROE jgcg i.firm_id i.year, vce(cluster firm_id)
est store DID_OLS

nbreg 负面新闻数_t1 esg Treat Post ESG_Treat ESG_Post Treat_Post ESG_Treat_Post ln_size ZCFZL ROE jgcg i.firm_id i.year, vce(cluster firm_id)
est store DID_负二项

poisson 负面新闻数_t1 esg Treat Post ESG_Treat ESG_Post Treat_Post ESG_Treat_Post ln_size ZCFZL ROE jgcg i.firm_id i.year, vce(cluster firm_id)
est store DID_泊松

* 12. 稳健性检验：剔除2020年（疫情年份）
preserve
drop if year == 2020
nbreg 负面新闻数_t1 esg Treat Post ESG_Treat ESG_Post Treat_Post ESG_Treat_Post ln_size ZCFZL ROE jgcg i.firm_id i.year, vce(cluster firm_id)
est store DID_剔除2020
restore

* 13. 异质性分析：按公司治理(jgcg)中位数分组
egen jgcg_med = pctile(jgcg), p(50) by(year)
gen high_jgcg = (jgcg >= jgcg_med)
gen low_jgcg  = (jgcg <  jgcg_med)

* 高治理组
nbreg 负面新闻数_t1 esg Treat ESG_Treat ln_size ZCFZL ROE jgcg i.firm_id i.year if high_jgcg, vce(cluster firm_id)
est store DID_高治理

* 低治理组
nbreg 负面新闻数_t1 esg Treat ESG_Treat ln_size ZCFZL ROE jgcg i.firm_id i.year if low_jgcg, vce(cluster firm_id)
est store DID_低治理

* 14. 输出所有结果（一键查看）
esttab 基准回归 DID_OLS DID_负二项 DID_泊松 DID_剔除2020 DID_高治理 DID_低治理, se star(* 0.1 ** 0.05 *** 0.01)
