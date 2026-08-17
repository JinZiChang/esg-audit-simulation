* 1. 安装工具
ssc install outreg2
ssc install winsor2
ssc install estout
ssc install coefplot
clear all

* 2. 导入数据
import excel "维度三数据库.xlsx", sheet("Sheet1") firstrow clear
cd "~/Desktop"
rename input input_metrics
rename outcome outcome_metrics

* 其他变量重命名
rename p audit_big4      
rename zsz total_mkt_cap 
rename jgcg inst_hold   
rename ROE roe           
rename ZCFZL leverage    
rename NHSYL net_profit 

* 3. 数据清洗
gen size = ln(total_mkt_cap)
winsor2 input_metrics outcome_metrics roe leverage size inst_hold, cuts(1 99) replace
drop if missing(outcome_metrics, input_metrics, audit_big4, size, roe)

* 4. 面板设定
encode stkcd, gen(firm_id)
sort firm_id year
tsset firm_id year

* 5. 多期DID构造（四大审计）
gen temp_year = cond(audit_big4==1, year, .)
bysort firm_id (year): egen first_treat_year = min(temp_year)
drop temp_year
gen rel_year = year - first_treat_year
bysort firm_id (year): gen Treat = !missing(first_treat_year)

* 生成事件窗口 [-5,9]，基准组为-1
capture drop rel_year_*
forvalues i = -5(1)9 {
    if `i' != -1 {
        gen rel_year_`i' = (rel_year==`i' & Treat==1)
    }
}

* ------------------------------------------------------------------------------
* 6. 核心回归：输入指标 → 结果指标（DID模型）
xtreg outcome_metrics input_metrics rel_year_* size roe leverage inst_hold i.year, fe vce(cluster firm_id)
est store did_main

* 7. 异质性分析（机构持股分组）
bysort year: egen inst_p70 = pctile(inst_hold), p(70)
gen high_inst = (inst_hold >= inst_p70)

xtreg outcome_metrics input_metrics rel_year_* size roe leverage inst_hold i.year if high_inst==1, fe vce(cluster firm_id)
est store did_high
xtreg outcome_metrics input_metrics rel_year_* size roe leverage inst_hold i.year if high_inst==0, fe vce(cluster firm_id)
est store did_low

* 8. 导出表格（输入+结果指标都在表里）
esttab did_main did_high did_low using "DID_输入输出结果.csv", replace se star(*0.1 **0.05 ***0.01)
