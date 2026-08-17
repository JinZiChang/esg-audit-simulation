* =============================================================================
* 维度二：四大审计与ESG评级预测力
* 模型：负二项回归（Negative Binomial）
* 被解释变量：负面新闻数_t1（t+1期负面事件计数）
* 核心解释变量：esg × Treat（四大审计下评级分歧度的预测效应）
* 额外检验：加入Post构建三重交互项 esg × Treat × Post
* 控制变量：ln_size ZCFZL ROE jgcg
* 固定效应：年度固定效应（企业与文章的"已控制个体特征"通过聚类标准误体现）
* 标准误：聚类到企业层面
* =============================================================================

clear all
set more off
capture log close

use "$DATA/dimension2_data.dta", clear

* -------- 数据清洗 --------
* 1%缩尾
winsor2 ln_size ZCFZL ROE jgcg, cuts(1 99) replace

* 删除缺失值
drop if missing(负面新闻数_t1, esg, Treat, Post, ln_size)

* 设定面板结构
gen id = firm_id
sort id year
xtset id year

* -------- 描述性统计 --------
estpost summarize 负面新闻数_t1 esg Treat Post ln_size ZCFZL ROE jgcg, detail
esttab using "$OUTPUT/desc_stats_d2.csv", replace ///
    cells("count(fmt(%9.0f)) mean(fmt(%9.3f)) sd(fmt(%9.3f)) min(fmt(%9.3f)) max(fmt(%9.3f))")

* =============================================================================
* 基准回归——负二项回归（核心模型）
* News_it+1 = β0 + β1*esg_it + β2*Treat_i + β3*Post_it
*           + β4*(esg×Treat)_it + β5*(esg×Post)_it
*           + β6*(Treat×Post)_it + β7*(esg×Treat×Post)_it
*           + ΣControls_it + λ_t + ε_it
* 核心关注：β4（esg×Treat）——水平效应
*           β7（esg×Treat×Post）——增量效应
* =============================================================================

* -------- (1) 基础对比：仅esg对负面新闻的影响 --------
nbreg 负面新闻数_t1 esg ln_size ZCFZL ROE jgcg i.year, vce(cluster id)
est store d2_baseline_ref

* -------- (2) 核心DDD模型：含三重交互项 --------
nbreg 负面新闻数_t1 esg Treat Post ESG_Treat ESG_Post Treat_Post ESG_Treat_Post ///
      ln_size ZCFZL ROE jgcg i.year, vce(cluster id)
est store d2_ddd_main

* -------- (3) OLS对比 --------
reg 负面新闻数_t1 esg Treat Post ESG_Treat ESG_Post Treat_Post ESG_Treat_Post ///
    ln_size ZCFZL ROE jgcg i.year, vce(cluster id)
est store d2_ols

* -------- (4) 泊松回归对比 --------
poisson 负面新闻数_t1 esg Treat Post ESG_Treat ESG_Post Treat_Post ESG_Treat_Post ///
        ln_size ZCFZL ROE jgcg i.year, vce(cluster id)
est store d2_poisson

* -------- (5) 稳健性：剔除2020年 --------
preserve
drop if year == 2020
nbreg 负面新闻数_t1 esg Treat Post ESG_Treat ESG_Post Treat_Post ESG_Treat_Post ///
      ln_size ZCFZL ROE jgcg i.year, vce(cluster id)
est store d2_no2020
restore

* -------- (6) 长期效应：滞后2期负面新闻 --------
gen 负面新闻数_t2 = L2.负面新闻数
nbreg 负面新闻数_t2 esg Treat Post ESG_Treat ESG_Post Treat_Post ESG_Treat_Post ///
      ln_size ZCFZL ROE jgcg i.year, vce(cluster id)
est store d2_longterm

* -------- 输出结果表格 --------
esttab d2_baseline_ref d2_ddd_main d2_ols d2_poisson d2_no2020 d2_longterm ///
    using "$OUTPUT/维度二_基准回归.csv", replace ///
    se star(* 0.1 ** 0.05 *** 0.01) ///
    title("表1 维度二：四大审计对ESG评级预测力的影响") ///
    scalars("N 观测值" "ll 对数似然值" "lnalpha 过度分散参数" "FE 年度固定效应")

display "========== 维度二分析完成 =========="
