* =============================================================================
* 维度三：四大审计与ESG评级颗粒度
* 模型：双向固定效应 + 事件研究法（多期DID动态模型）
* 被解释变量：outcome_metrics（结果型指标数量）
* 核心解释变量：rel_year_k（相对年份虚拟变量，基准组为-1）
* 控制变量：size roe leverage inst_hold net_profit
* 固定效应：年度固定效应
* =============================================================================

clear all
set more off
capture log close

use "$DATA/dimension3_data.dta", clear

* -------- 数据清洗 --------
* 统一变量名（与.do文件一致）
rename audit_big4 p
rename size total_mkt_cap
rename inst_hold jgcg
rename roe ROE
rename leverage ZCFZL
rename net_profit NHSYL

* 取对数规模
gen size = ln(total_mkt_cap)

* 1%缩尾
winsor2 outcome_metrics input_metrics ROE ZCFZL size jgcg NHSYL, cuts(1 99) replace

* 删除缺失值
drop if missing(outcome_metrics, input_metrics, p, size)

* 设定面板结构
gen id = firm_id
sort id year
xtset id year

* -------- 生成事件窗口变量 --------
* 使用.do文件中的变量名体系
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

* 生成10x变量名（与用户.do文件一致）
forvalues i = 6/9 {
    gen rel_year_10`i' = (rel_year == `i' & Treat == 1)
}

* -------- 描述性统计 --------
estpost summarize outcome_metrics input_metrics size ROE ZCFZL jgcg NHSYL, detail
esttab using "$OUTPUT/desc_stats_d3.csv", replace ///
    cells("count(fmt(%9.0f)) mean(fmt(%9.3f)) sd(fmt(%9.3f)) min(fmt(%9.3f)) max(fmt(%9.3f))")

* =============================================================================
* 基准回归——事件研究法
* Granularity_it = γ0 + Σ(γk × rel_year_k_it) + ΣControls_it + λ_t + ε_it
* 基准组为相对年份-1
* =============================================================================

* -------- (1) 核心DID动态模型 --------
xtreg outcome_metrics input_metrics ///
       rel_year_m5 rel_year_m4 rel_year_m3 rel_year_m2 ///
       rel_year_0 rel_year_1 rel_year_2 rel_year_3 rel_year_4 rel_year_5 ///
       rel_year_6 rel_year_7 rel_year_8 rel_year_9 ///
       size ROE ZCFZL jgcg NHSYL i.year, fe vce(cluster id)
est store d3_did_main

* -------- (2) 动态效应图 --------
coefplot d3_did_main, ///
    keep(rel_year_m5 rel_year_m4 rel_year_m3 rel_year_m2 ///
         rel_year_0 rel_year_1 rel_year_2 rel_year_3 rel_year_4 rel_year_5 ///
         rel_year_6 rel_year_7 rel_year_8 rel_year_9) ///
    order(rel_year_m5 rel_year_m4 rel_year_m3 rel_year_m2 ///
          rel_year_0 rel_year_1 rel_year_2 rel_year_3 rel_year_4 rel_year_5 ///
          rel_year_6 rel_year_7 rel_year_8 rel_year_9) ///
    coeflabels(rel_year_m5="-5" rel_year_m4="-4" rel_year_m3="-3" ///
               rel_year_m2="-2" rel_year_0="0" rel_year_1="1" ///
               rel_year_2="2" rel_year_3="3" rel_year_4="4" ///
               rel_year_5="5" rel_year_6="6" rel_year_7="7" ///
               rel_year_8="8" rel_year_9="9") ///
    vertical yline(0, lcolor(red) lwidth(medium)) ///
    xline(4.5, lcolor(gs10) lpattern(dash)) ///
    ciopts(lcolor(black) lwidth(thin)) ///
    title("四大审计对ESG评级颗粒度的动态效应") ///
    note("注：基准期为相对年份-1；虚线左侧为审计前各期") ///
    graphregion(color(white)) scheme(s2color)
graph export "$OUTPUT/动态效应_颗粒度.png", replace width(1200)

* -------- (3) 稳健性：更换基准期（以-2为基准） --------
capture drop rel_year_alt_*
gen rel_year_alt_m5 = (rel_year == -5 & Treat == 1)
gen rel_year_alt_m4 = (rel_year == -4 & Treat == 1)
gen rel_year_alt_m3 = (rel_year == -3 & Treat == 1)
gen rel_year_alt_m1 = (rel_year == -1 & Treat == 1)
gen rel_year_alt_0  = (rel_year == 0  & Treat == 1)
gen rel_year_alt_1  = (rel_year == 1  & Treat == 1)
gen rel_year_alt_2  = (rel_year == 2  & Treat == 1)
gen rel_year_alt_3  = (rel_year == 3  & Treat == 1)
gen rel_year_alt_4  = (rel_year == 4  & Treat == 1)
gen rel_year_alt_5  = (rel_year == 5  & Treat == 1)
gen rel_year_alt_6  = (rel_year == 6  & Treat == 1)
gen rel_year_alt_7  = (rel_year == 7  & Treat == 1)
gen rel_year_alt_8  = (rel_year == 8  & Treat == 1)
gen rel_year_alt_9  = (rel_year == 9  & Treat == 1)
forvalues i = 6/9 {
    gen rel_year_alt_10`i' = (rel_year == `i' & Treat == 1)
}

xtreg outcome_metrics input_metrics ///
       rel_year_alt_m5 rel_year_alt_m4 rel_year_alt_m3 ///
       rel_year_alt_m1 rel_year_alt_0 rel_year_alt_1 rel_year_alt_2 ///
       rel_year_alt_3 rel_year_alt_4 rel_year_alt_5 ///
       rel_year_alt_6 rel_year_alt_7 rel_year_alt_8 rel_year_alt_9 ///
       size ROE ZCFZL jgcg NHSYL i.year, fe vce(cluster id)
est store d3_alt_baseline

* -------- (4) 稳健性：缩短窗口（[-3,5]） --------
capture drop rel_year_short_*
gen rel_year_short_m3 = (rel_year == -3 & Treat == 1)
gen rel_year_short_m2 = (rel_year == -2 & Treat == 1)
gen rel_year_short_0  = (rel_year == 0  & Treat == 1)
gen rel_year_short_1  = (rel_year == 1  & Treat == 1)
gen rel_year_short_2  = (rel_year == 2  & Treat == 1)
gen rel_year_short_3  = (rel_year == 3  & Treat == 1)
gen rel_year_short_4  = (rel_year == 4  & Treat == 1)
gen rel_year_short_5  = (rel_year == 5  & Treat == 1)
xtreg outcome_metrics input_metrics ///
       rel_year_short_m3 rel_year_short_m2 ///
       rel_year_short_0 rel_year_short_1 rel_year_short_2 ///
       rel_year_short_3 rel_year_short_4 rel_year_short_5 ///
       size ROE ZCFZL jgcg NHSYL i.year, fe vce(cluster id)
est store d3_short_window

* -------- 输出结果表格 --------
esttab d3_did_main d3_alt_baseline d3_short_window ///
    using "$OUTPUT/维度三_基准回归.csv", replace ///
    se star(* 0.1 ** 0.05 *** 0.01) ///
    title("表1 维度三：四大审计对ESG评级颗粒度的影响") ///
    scalars("N 观测值" "FE 企业固定效应" "FE_year 年度固定效应")

display "========== 维度三分析完成 =========="
