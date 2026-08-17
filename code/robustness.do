* =============================================================================
* 稳健性检验
* 包含：PSM-DID、安慰剂检验、替换变量与样本调整
* =============================================================================

clear all
set more off
capture log close

* =============================================================================
* 一、维度一稳健性检验
* =============================================================================
use "$DATA/dimension1_data.dta", clear
gen id = firm_id
sort id year
xtset id year

* -------- (1) PSM-DID --------
* 以企业规模、资产负债率、ROE、机构持股为协变量
* 1:1 最近邻匹配

* Logit回归估计倾向得分
logit Treat SIZE LEV ROE ISR, vce(cluster id)
predict pscore, pr

* 1:1最近邻匹配
psmatch2 Treat, pscore(pscore) neighbor(1) caliper(0.05) common

* 基于匹配后样本重新回归
xtreg esg DID SIZE ISR ROE ARR TE LEV i.year if _weight != 0 & _weight != ., ///
      fe vce(cluster id)
est store d1_psm

* 输出
esttab d1_psm using "$OUTPUT/稳健性_PSM_DID.csv", replace ///
    se star(* 0.1 ** 0.05 *** 0.01) ///
    title("PSM-DID稳健性检验")

* -------- (2) 安慰剂检验（随机分配处理组）--------
* 重复1000次，记录伪DID系数
set seed 20260722

preserve
gen fake_DID = .
forvalues i = 1/1000 {
    * 随机分配处理组（公司层面独立于真实Treat）
    capture drop fake_Treat fake_first_year fake_Post fake_DID_i
    bysort id: gen fake_Treat = (uniform() < 0.30) if _n == 1
    bysort id: replace fake_Treat = fake_Treat[_n-1] if missing(fake_Treat)
    
    * 随机分配首次审计年份（公司层面恒定）
    bysort id: gen fake_first_year = 2016 + floor(uniform()*5) if _n == 1
    bysort id: replace fake_first_year = fake_first_year[_n-1] if missing(fake_first_year)
    gen fake_Post = (year >= fake_first_year & !missing(fake_first_year)) if fake_Treat == 1
    replace fake_Post = 0 if fake_Treat == 0
    gen fake_DID_i = fake_Treat * fake_Post
    
    * 回归
    xtreg esg fake_DID_i SIZE ISR ROE ARR TE LEV i.year if _weight != 0 & _weight != ., ///
          fe vce(cluster id)
    capture replace fake_DID = _b[fake_DID_i] in `i'
    capture drop shuffle fake_Treat fake_first_year fake_Post fake_DID_i
}

* 绘制安慰剂检验分布图
summarize fake_DID
local true_coef = -0.055
local mu = r(mean)
local sigma = r(sd)

* 直方图 + 正态拟合
histogram fake_DID, frequency normal ///
    xline(`true_coef', lcolor(red) lwidth(medium)) ///
    title("安慰剂检验：随机处理组DID系数分布 (1000次)") ///
    note("红色虚线为真实DID系数 (−0.055)") ///
    graphregion(color(white)) scheme(s2color)
graph export "$OUTPUT/安慰剂检验_分歧度.png", replace width(1200)

restore

* =============================================================================
* 二、维度二稳健性检验（在dimension2中已包含部分）
* =============================================================================
use "$DATA/dimension2_data.dta", clear
gen id = firm_id
sort id year
xtset id year

* 生成log被解释变量（用于OLS对比）
gen ln_neg = ln(负面新闻数_t1 + 1)

* (a) 基准OLS
reg ln_neg esg Treat Post ESG_Treat ESG_Post Treat_Post ESG_Treat_Post ///
    ln_size ZCFZL ROE jgcg i.id i.year, vce(cluster id)
est store d2_ols_rob

* (b) 仅时间固定效应（不控制个体FE）
nbreg 负面新闻数_t1 esg Treat Post ESG_Treat ESG_Post Treat_Post ESG_Treat_Post ///
      ln_size ZCFZL ROE jgcg i.year, vce(cluster id)
est store d2_timefe

* (c) 去掉jgcg控制变量
nbreg 负面新闻数_t1 esg Treat Post ESG_Treat ESG_Post Treat_Post ESG_Treat_Post ///
      ln_size ZCFZL ROE i.id i.year, vce(cluster id)
est store d2_nojgcg

esttab d2_ols_rob d2_timefe d2_nojgcg using "$OUTPUT/稳健性_维度二.csv", replace ///
    se star(* 0.1 ** 0.05 *** 0.01)

* =============================================================================
* 三、维度三稳健性检验（在dimension3中已包含）
* =============================================================================

display "========== 稳健性检验完成 =========="
