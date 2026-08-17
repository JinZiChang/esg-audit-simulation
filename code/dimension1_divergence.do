* =============================================================================
* 维度一：四大审计与ESG评级分歧度
* 模型：交错DID（Staggered Difference-in-Differences）
* 被解释变量：esg（基础评级分歧度）/ esg_w（加权评级分歧度）
* 核心解释变量：DID = Treat × Post
* 控制变量：SIZE ISR ROE ARR TE LEV
* 固定效应：企业 + 年度
* 标准误：聚类到企业层面
* =============================================================================

clear all
set more off
capture log close

use "$DATA/dimension1_data.dta", clear

* -------- 数据清洗 --------
* 1%缩尾处理
winsor2 SIZE ISR ROE ARR TE LEV, cuts(1 99) replace

* 删除缺失值
drop if missing(esg, DID, SIZE)

* 设定面板结构
gen id = firm_id
sort id year
xtset id year

* -------- 描述性统计 --------
estpost summarize esg esg_w DID SIZE ISR ROE ARR TE LEV, detail
esttab using "$OUTPUT/desc_stats_d1.csv", replace ///
    cells("count(fmt(%9.0f)) mean(fmt(%9.3f)) sd(fmt(%9.3f)) min(fmt(%9.3f)) max(fmt(%9.3f))") ///
    title("维度一：描述性统计")

* -------- 基准回归：表1列(1) --------
* Disagree_it = α0 + α1*DID_it + ΣControls_it + μ_i + λ_t + ε_it

xtreg esg DID SIZE ISR ROE ARR TE LEV i.year, fe vce(cluster id)
est store d1_baseline

* -------- 稳健性检验：加权分歧度 表1列(2) --------
xtreg esg_w DID SIZE ISR ROE ARR TE LEV i.year, fe vce(cluster id)
est store d1_weighted

* -------- 平行趋势检验 --------
* 以pre8为基准组，生成相对时间虚拟变量
xtreg esg pre7 pre6 pre5 pre4 pre3 pre2 pre1 current ///
      las_1 las_2 las_3 las_4 las_5 las_6 las_7 las_8 las_9 ///
      SIZE ISR ROE ARR TE LEV i.year, fe vce(cluster id)
est store d1_pretrend

* 平行趋势图
coefplot d1_pretrend, ///
    keep(pre7 pre6 pre5 pre4 pre3 pre2 pre1 current ///
         las_1 las_2 las_3 las_4 las_5 las_6 las_7 las_8 las_9) ///
    order(pre7 pre6 pre5 pre4 pre3 pre2 pre1 current ///
          las_1 las_2 las_3 las_4 las_5 las_6 las_7 las_8 las_9) ///
    vertical yline(0, lcolor(red) lwidth(medium)) ///
    xline(8.5, lcolor(gs10) lpattern(dash)) ///
    ciopts(lcolor(black) lwidth(thin)) ///
    coeflabels(pre7="-7" pre6="-6" pre5="-5" pre4="-4" ///
               pre3="-3" pre2="-2" pre1="-1" current="0" ///
               las_1="1" las_2="2" las_3="3" las_4="4" ///
               las_5="5" las_6="6" las_7="7" las_8="8" las_9="9") ///
    title("平行趋势检验：四大审计对ESG评级分歧度的动态效应") ///
    note("注：基准期为处理前8期(pre8)；虚线右侧为处理当期及之后各期") ///
    graphregion(color(white)) scheme(s2color)

graph export "$OUTPUT/平行趋势_分歧度.png", replace width(1200)

* -------- 输出结果表格 --------
esttab d1_baseline d1_weighted using "$OUTPUT/维度一_基准回归.csv", replace ///
    se star(* 0.1 ** 0.05 *** 0.01) ///
    title("表1 维度一：四大审计对ESG评级分歧度的影响") ///
    scalars("N 观测值" "r2_w 组内R²" "FE 企业固定效应" "FE_year 年度固定效应")

display "========== 维度一分析完成 =========="
