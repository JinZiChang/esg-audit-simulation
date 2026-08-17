* =============================================================================
* 模拟数据生成（按论文结果方向校准）
* 数据结构：维度一为2010-2022年面板，维度二/三维为2013-2022年面板，A股上市公司
* 说明：数据为模拟数据，系数依据论文表2/3/4的方向与量级反向设定，
*       用于在不泄露真实数据的前提下验证代码可运行性与结论方向。
* =============================================================================

clear all
set more off

* ---------- 维度一：ESG评级分歧度数据 ----------
* 样本量约 4,437 公司-年度观测值（2010-2022年面板）
* 说明：面板前推至2010年，使事件研究基准期(pre8)有足够观测，
*       避免基准期样本过薄导致系数整体偏移
* 变量：firm_id year esg esg_w DID SIZE ISR ROE ARR TE LEV Treat Post

clear
set obs 4437

gen firm_id = ceil(_n / 13)
bysort firm_id: gen year = 2009 + _n
drop if year > 2022

set seed 20260722
gen Treat = (uniform() < 0.30)
bysort firm_id: replace Treat = Treat[1]

* 首次被四大审计年份（2013-2021，公司层面恒定抽取一次）
gen ft_draw = 2013 + floor(uniform()*9)
bysort firm_id: replace ft_draw = ft_draw[1]
gen first_treat_year = ft_draw if Treat == 1
drop ft_draw
gen Post = (year >= first_treat_year & !missing(first_treat_year))
replace Post = 0 if Treat == 0
gen DID = Treat * Post

* 控制变量（量纲与论文描述性统计不同，仅用于回归方向校准）
gen SIZE = 1e7 + 5e6 * uniform()
gen ISR  = 30 + 40 * uniform()
gen ROE  = 8 + 10 * uniform()
gen ARR  = 5 + 15 * uniform()
gen TE   = 5e6 + 3e6 * uniform()
gen LEV  = 40 + 25 * uniform()

* 相对时间变量（平行趋势检验用）
gen rel_year = year - first_treat_year if !missing(first_treat_year)
forvalues i = 8(-1)1 {
    gen pre`i' = (rel_year == -`i' & Treat == 1)
}
gen current = (rel_year == 0 & Treat == 1)
forvalues i = 1/9 {
    gen las_`i' = (rel_year == `i' & Treat == 1)
}

* 动态处理效应：当期起显著为负，处理后各期持续为负且显著（对应论文图1）
* 各期效应量级参考 DID 回归系数约 -0.057*** 的平均水平
gen treat_effect = -0.055*current - 0.051*las_1 - 0.055*las_2 - 0.060*las_3 ///
                 - 0.064*las_4 - 0.069*las_5 - 0.069*las_6 - 0.074*las_7 ///
                 - 0.083*las_8 - 0.074*las_9

* 年度效应（趋势项，用于使 R2 量级接近论文；年份固定效应可将其吸收）
bysort year: gen year_effect = 0.0335 * (year - 2010)

* 被解释变量：ESG评级分歧度
* 论文：DID 系数约 -0.057***，控制变量方向：SIZE+ ISR- ROE+ ARR+ TE- LEV-
gen esg = 0.45 + year_effect + treat_effect ///
        + 1.5e-8 * SIZE - 0.0005 * ISR + 0.0001 * ROE ///
        + 0.0012 * ARR - 8e-9 * TE - 0.0004 * LEV + rnormal(0, 0.115)

* 加权分歧度（用于稳健性）
gen esg_w = esg + rnormal(0, 0.015)

* 确保 esg 为正（评级分歧度为正值）
replace esg = abs(esg)
replace esg_w = abs(esg_w)

sort firm_id year
save "$DATA/dimension1_data.dta", replace

* ---------- 维度二：ESG评级预测力数据 ----------
* 样本量约 3,329 公司-年度观测值
* 变量：firm_id year 负面新闻数_t1 esg Treat Post ln_size ZCFZL ROE jgcg

clear
set obs 3329

gen firm_id = ceil(_n / 10)
bysort firm_id: gen year = 2012 + _n
drop if year > 2022

set seed 20260723
gen Treat = (uniform() < 0.30)
bysort firm_id: replace Treat = Treat[1]

* 真实审计时点（处理组）与伪时点（控制组）
* 控制组也赋予伪Post，避免 Post 与 Treat*Post 完全共线，使三重交互项可估
gen ft_draw = 2016 + floor(uniform()*5)
bysort firm_id: replace ft_draw = ft_draw[1]
gen first_treat_year = ft_draw if Treat == 1
drop ft_draw
* 控制组也赋予伪审计时点（公司层面恒定），避免 Post 与 Treat*Post 完全共线
gen pseudo_year = 2016 + floor(uniform()*5)
bysort firm_id: replace pseudo_year = pseudo_year[1]
replace pseudo_year = first_treat_year if Treat == 1
gen Post = (year >= pseudo_year)
gen DID = Treat * Post

* esg（分歧度）
gen esg = abs(0.30 + rnormal(0, 0.25))

* 控制变量
gen ln_size = 15 + 2 * uniform()
gen ZCFZL   = 40 + 25 * uniform()
gen ROE     = 8 + 10 * uniform()
gen jgcg    = 50 + 30 * uniform()

* 企业随机效应（用于产生聚类效应，使次要项 t 值量级接近论文）
bysort firm_id: gen firm_re = rnormal(0, 0.25)

* 负面新闻数（计数变量，负二项分布，alpha=0.208 对应 lnalpha≈-1.57）
* 采用 Gamma-Poisson 混合构造（rnbinomial 在本机 Stata 中对 r>1 返回缺失值）
* 论文核心：esg*Treat 系数约 1.168**（显著为正）
* 异质性：低机构持股组 esg*Treat 约 1.855***，高机构持股组约 0.595（不显著）
bysort year: egen jgcg_med = median(jgcg)
gen low_inst = (jgcg < jgcg_med)

gen lambda = exp(-3.229 - 0.232 * esg - 0.059 * Treat - 0.083 * Post ///
               + 0.595 * esg * Treat + 0.538 * esg * Post ///
               - 0.038 * Treat * Post - 0.210 * esg * Treat * Post ///
               + 1.260 * esg * Treat * low_inst ///
               + 0.359 * ln_size - 0.0065 * jgcg - 0.002 * ROE + 0.004 * ZCFZL ///
               + firm_re)
gen nb_overdisp = rgamma(4.8, lambda / 4.8)
gen 负面新闻数 = rpoisson(nb_overdisp)
gen 负面新闻数_t1 = 负面新闻数

* 生成交互项
gen ESG_Treat      = esg * Treat
gen ESG_Post       = esg * Post
gen Treat_Post     = Treat * Post
gen ESG_Treat_Post = esg * Treat * Post

sort firm_id year
save "$DATA/dimension2_data.dta", replace

* ---------- 维度三：ESG评级颗粒度数据 ----------
* 样本量约 2,182 公司-年度观测值
* 变量：firm_id year outcome_metrics input_metrics audit_big4 size roe leverage inst_hold net_profit

clear
set obs 2182

gen firm_id = ceil(_n / 10)
bysort firm_id: gen year = 2012 + _n
drop if year > 2022

set seed 20260724
gen audit_big4 = (uniform() < 0.14)
bysort firm_id: replace audit_big4 = audit_big4[1]

* 首次审计年份 2013-2018（覆盖审计后-5至+9期的完整事件窗口）
gen ft_draw = 2013 + floor(uniform()*6)
bysort firm_id: replace ft_draw = ft_draw[1]
gen first_treat_year = ft_draw if audit_big4 == 1
drop ft_draw

gen Treat = audit_big4
gen rel_year = year - first_treat_year if !missing(first_treat_year)

* 控制变量
gen size        = 10 + 10 * uniform()
gen roe         = 8 + 10 * uniform()
gen leverage    = 40 + 25 * uniform()
gen inst_hold   = 30 + 40 * uniform()
gen net_profit  = 5 + 15 * uniform()

* 生成相对年份虚拟变量（基准组为-1，变量名使用合法 Stata 命名）
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

* 年度固定效应（量级与论文一致）
gen year_fe = 0
replace year_fe = -19.652 if year == 2014
replace year_fe = -0.444  if year == 2015
replace year_fe = -2.937  if year == 2016
replace year_fe = 1.406   if year == 2017
replace year_fe = 5.900   if year == 2018
replace year_fe = 14.104  if year == 2019
replace year_fe = 20.155  if year == 2020
replace year_fe = 30.013  if year == 2021
replace year_fe = 45.775  if year == 2022

* 机构持股年度中位数分组（异质性检验用）
bysort year: egen inst_med = median(inst_hold)
gen low_inst3 = (inst_hold < inst_med)

* 结果指标数量（被解释变量）
* 论文：审计后6-9年显著为正；低机构持股组效应更强更持续
gen outcome_metrics = 30 + 14 * ln(size) + 0.50 * roe - 0.40 * net_profit ///
                    + 0.01 * leverage + 0.05 * inst_hold + year_fe ///
                    + 6.112  * rel_year_m5 - 5.142 * rel_year_m4 ///
                    - 8.747  * rel_year_m3 + 0.338  * rel_year_m2 ///
                    + 3.000  * rel_year_0 - 3.000  * rel_year_1 ///
                    + 2.000  * rel_year_2 + 0.000  * rel_year_3 ///
                    + 5.000  * rel_year_4 + 4.000  * rel_year_5 ///
                    + 26.009 * rel_year_6 + 34.716 * rel_year_7 ///
                    + 48.415 * rel_year_8 + 20.000 * rel_year_9 ///
                    + 11.849 * rel_year_6 * low_inst3 ///
                    + 20.543 * rel_year_7 * low_inst3 ///
                    + 9.761  * rel_year_8 * low_inst3 ///
                    + 50.000 * rel_year_9 * low_inst3 ///
                    + rnormal(0, 28)

* 投入指标数量
gen input_metrics = 20 + 0.5 * size + rnormal(0, 5)

sort firm_id year
save "$DATA/dimension3_data.dta", replace

display "========================================"
display "  模拟数据生成完成（按论文方向校准）"
display "  维度一样本量: " _N
display "========================================"
