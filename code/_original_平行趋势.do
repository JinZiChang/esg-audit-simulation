coefplot multi_did_main, ///
    keep(rel_year_m4 rel_year_m3 rel_year_m2 rel_year_0 rel_year_1 rel_year_2 rel_year_3 rel_year_4) ///
    order(rel_year_m4 rel_year_m3 rel_year_m2 rel_year_0 rel_year_1 rel_year_2 rel_year_3 rel_year_4) ///
    coeflabels( ///
        rel_year_m4 = "-4" ///
        rel_year_m3 = "-3" ///
        rel_year_m2 = "-2" ///
        rel_year_0  = "0"  ///
        rel_year_1  = "1"  ///
        rel_year_2  = "2"  ///
        rel_year_3  = "3"  ///
        rel_year_4  = "4") ///
    vertical ///
    yline(0, lcolor(red) lwidth(medium)) ///
    ciopts(lcolor(black) lwidth(thin)) ///
    xline(3.5, lcolor(gs10) lpattern(dash)) ///
    title("四大审计对ESG评级颗粒度的动态效应") ///
    note("注：基准期为相对年份-1；*** p<0.01, ** p<0.05, * p<0.1") ///
    graphregion(color(white)) ///
    scheme(s2color)

graph export "多期DID动态效应图.png", replace width(1200)