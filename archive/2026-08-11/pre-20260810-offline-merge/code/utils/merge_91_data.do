clear all
use "C:\Users\SRDAR052025002\Desktop\Indigenous_Policy_Project\data\raw_data\economic_survey\91年\data91_1.dta", clear

summarize id, meanonly
local maxid = r(max)

append using "C:\Users\SRDAR052025002\Desktop\Indigenous_Policy_Project\data\raw_data\economic_survey\91年\data91_2.dta", gen(from_dt2)

replace id = id + `maxid' if from_dt2 == 1

duplicates report id

save "C:\Users\SRDAR052025002\Desktop\Indigenous_Policy_Project\data\raw_data\economic_survey\91年\data91.dta"