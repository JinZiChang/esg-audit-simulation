* =============================================================================
* 平行趋势检验
* 维度一：评级分歧度平行趋势（以pre8为基准）
* 维度三：评级颗粒度平行趋势（事件研究法，以-1为基准）
* =============================================================================

clear all
set more off
capture log close

* -------- 维度一 平行趋势 --------
use "$DATA/dimension1_data.dta", clear
gen id = firm_id
sort id year
xtset id year

* 生成处理前8期-处理后9期虚拟变量（以pre8为基准）
* 在data_generation中已生成 pre1-pre8, current, las_1-las_9

* 平行趋势回归
xtreg esg pre7 pre6 pre5 pre4 pre3 pre2 pre1 current ///
      las_1 las_2 las_3 las_4 las_5 las_6 las_7 las_8 las_9 ///
      SIZE ISR ROE ARR TE LEV i.year, fe vce(cluster id)
est store pretrend_d1

* 绘制平行趋势图
coefplot pretrend_d1, ///
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
    title("图1 平行趋势检验：四大审计对ESG评级分歧度的动态效应") ///
    note("注：基准期为处理前8期(pre8)；虚线右侧为处理当期及之后各期") ///
    graphregion(color(white)) scheme(s2color)
graph export "$OUTPUT/图1_平行趋势_分歧度.png", replace width(1200)

* -------- 维度三 平行趋势（事件研究图）--------
use "$DATA/dimension3_data.dta", clear
gen id = firm_id
sort id year
xtset id year

rename audit_big4 p
rename size total_mkt_cap
rename inst_hold jgcg
rename roe ROE
rename leverage ZCFZL
rename net_profit NHSYL
gen size = ln(total_mkt_cap)
winsor2 outcome_metrics ROE ZCFZL size jgcg NHSYL, cuts(1 99) replace

* 生成事件窗口
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

* 事件研究回归
xtreg outcome_metrics rel_year_m5 rel_year_m4 rel_year_m3 rel_year_m2 ///
       rel_year_0 rel_year_1 rel_year_2 rel_year_3 rel_year_4 rel_year_5 ///
       rel_year_6 rel_year_7 rel_year_8 rel_year_9 ///
       size ROE ZCFZL jgcg NHSYL i.year, fe vce(cluster id)
est store eventstudy_d3

* 事件研究图
coefplot eventstudy_d3, ///
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
    title("图2 事件研究法：四大审计对ESG评级颗粒度的动态效应") ///
    note("注：基准期为相对年份-1；虚线左侧为审计前各期") ///
    graphregion(color(white)) scheme(s2color)
graph export "$OUTPUT/图2_事件研究_颗粒度.png", replace width(1200)

display "========== 平行趋势检验完成 =========="
