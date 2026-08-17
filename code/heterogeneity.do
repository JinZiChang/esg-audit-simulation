* =============================================================================
* 异质性分析：按机构持股比例分组
* 理论逻辑：内外部治理的互补/替代效应
* 分组标准：机构持股比例的年度中位数
* =============================================================================

clear all
set more off
capture log close

* =============================================================================
* 维度二异质性：四大审计 × ESG评级预测力
* =============================================================================
use "$DATA/dimension2_data.dta", clear
gen id = firm_id
sort id year
xtset id year

* 年度中位数分组
capture drop inst_med
capture drop high_inst
capture drop low_inst
bysort year: egen inst_med = median(jgcg)
gen high_inst = (jgcg >= inst_med)
gen low_inst  = (jgcg < inst_med)

* 高机构持股组
nbreg 负面新闻数_t1 esg Treat ESG_Treat ln_size ZCFZL ROE jgcg i.id i.year ///
      if high_inst == 1, vce(cluster id)
est store d2_high_inst

* 低机构持股组
nbreg 负面新闻数_t1 esg Treat ESG_Treat ln_size ZCFZL ROE jgcg i.id i.year ///
      if low_inst == 1, vce(cluster id)
est store d2_low_inst

* 输出表格
esttab d2_high_inst d2_low_inst using "$OUTPUT/异质性_维度二.csv", replace ///
    se star(* 0.1 ** 0.05 *** 0.01) ///
    title("表2 维度二异质性分析：机构持股分组") ///
    scalars("N 观测值" "ll 对数似然值")

* =============================================================================
* 维度三异质性：四大审计 × ESG评级颗粒度
* =============================================================================
use "$DATA/dimension3_data.dta", clear
gen id = firm_id
sort id year
xtset id year

* 统一变量名
rename audit_big4 p
rename size total_mkt_cap
rename inst_hold jgcg
rename roe ROE
rename leverage ZCFZL
rename net_profit NHSYL
gen size = ln(total_mkt_cap)
winsor2 outcome_metrics ROE ZCFZL size jgcg NHSYL, cuts(1 99) replace
drop if missing(outcome_metrics, p, size)

* 生成rel_year变量
capture drop rel_year_*
gen rel_year_m5 = (rel_year == -5 & Treat == 1)
gen rel_year_m4 = (rel_year == -4 & Treat == 1)
gen rel_year_m3 = (rel_year == -3 & Treat == 1)
gen rel_year_m2 = (rel_year == -2 & Treat == 1)
gen rel_year_0  = (rel_year == 0  & Treat == 1)
gen rel_year_1  = (rel_year == 1  & Treat == 1)
gen rel_year_2  = (rel_year == 2  & Treat == 1)
gen rel_year_3  = (rel_year == 3  & Treat == 1)
gen rel_year_4  = (rel_year == 4  & Treat == 1)
gen rel_year_5  = (rel_year == 5  & Treat == 1)
gen rel_year_6  = (rel_year == 6  & Treat == 1)
gen rel_year_7  = (rel_year == 7  & Treat == 1)
gen rel_year_8  = (rel_year == 8  & Treat == 1)
gen rel_year_9  = (rel_year == 9  & Treat == 1)
forvalues i = 6/9 {
    gen rel_year_10`i' = (rel_year == `i' & Treat == 1)
}

* 年度中位数分组
capture drop inst_med
capture drop high_inst
capture drop low_inst
bysort year: egen inst_med = median(jgcg)
gen high_inst = (jgcg >= inst_med)
gen low_inst  = (jgcg < inst_med)

* 高机构持股组
xtreg outcome_metrics rel_year_m5 rel_year_m4 rel_year_m3 rel_year_m2 ///
       rel_year_0 rel_year_1 rel_year_2 rel_year_3 rel_year_4 rel_year_5 ///
       rel_year_6 rel_year_7 rel_year_8 rel_year_9 ///
       size ROE ZCFZL jgcg NHSYL i.year if high_inst == 1, fe vce(cluster id)
est store d3_high_inst

* 低机构持股组
xtreg outcome_metrics rel_year_m5 rel_year_m4 rel_year_m3 rel_year_m2 ///
       rel_year_0 rel_year_1 rel_year_2 rel_year_3 rel_year_4 rel_year_5 ///
       rel_year_6 rel_year_7 rel_year_8 rel_year_9 ///
       size ROE ZCFZL jgcg NHSYL i.year if low_inst == 1, fe vce(cluster id)
est store d3_low_inst

* 输出表格
esttab d3_high_inst d3_low_inst using "$OUTPUT/异质性_维度三.csv", replace ///
    se star(* 0.1 ** 0.05 *** 0.01) ///
    title("表2 维度三异质性分析：机构持股分组") ///
    scalars("N 观测值" "FE 企业固定效应" "FE_year 年度固定效应")

display "========== 异质性分析完成 =========="
