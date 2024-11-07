import delimited "C:\Users\hklapper\Dropbox\Empirical Paper on DAOs (MvHxHK)\Data\processed\proposals.csv"

encode space, gen(space_id)
encode type, gen(type_numeric)
tabulate type, generate(type_d)

xtset space_id

reghdfe votes, absorb(space_id) cluster(space_id)

gen log_votes = log(votes)
gen log_len = log(prps_len)


reghdfe log_votes prps_stub i.type_numeric log_len topic_0 topic_1 topic_2 ///
	topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 topic_9 topic_10 topic_11 ///
	topic_12 topic_13 topic_14 topic_15 topic_16 topic_17 topic_18 topic_19 ///
	prps_created quorum, absorb(space_id) cluster(space_id)

reghdfe log_votes  i.type_numeric , absorb(space_id) cluster(space_id)

//prps_stub log_len

corr topic_* type_d*

mlogit type_numeric topic_*, noconstant