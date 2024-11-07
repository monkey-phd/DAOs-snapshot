
/*
//Import raw file by Magnus
import delimited "$dao_folder\input\data_clean_drop.csv", ///
	bindquote(strict) case(preserve) maxquotedrows(unlimited) clear

//drop body


save "$dao_folder/processed/magnus_export.dta", replace
*/

//Import raw file by Helge
import delimited "$dao_folder\input\data_clean.csv", ///
	bindquote(strict) case(preserve) maxquotedrows(unlimited) clear

save "$dao_folder/processed/helge_export.dta", replace
