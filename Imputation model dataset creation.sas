/****************************************************************************************************/
/*	Code to Impute Racial and Socio Demographic Clientel of Hospitals by ER Visit Patient Zip Code	*/
/*																									*/
/*	Programmed By: Camille Chaustre McNally															*/
/*	Date: 05/09/2020																				*/
/*																									*/
/*	Description: Code takes data of aggregated ED admission visits stratfied by hospital 			*/
/*		and patient zip code. This is matched with data from ACS 5-year estimates, which are used	*/
/*		as weights to impute patient demographics when summed by hospital.							*/
/****************************************************************************************************/

libname data "R:\EmergencyEvents\2019_nCoV\IDT\Allocation Algorithms\ED Admission Numbers and Zip Codes\data";

/*	First, import data into SAS. The data for this program consists of ER admissions by .	*/

/*	Aggregated patient data stratified by facility, date, and zip code	of patient residence		*/
data data.er_zip1;
	format zcta $7. ;
	set data.er_zip;
	if anyalpha(zipcode)=0 then zcta = zipcode;
	else zcta = "NA";
run;

/*	Keep needed variables from ACS data.													*/

/*	Racial data from ACS table ACSDP5Y2018.DP05 											*/
data data.acsrace1;
	set data.acsrace;
	keep geo_id name DP05_0077PE DP05_0078PE DP05_0079PE DP05_0080PE DP05_0071PE;
run;

/*	Poverty data from ACS table ACSST5Y2018.S1701											*/
data data.acspov1;
	set data.acspov;
	keep geo_id name S1701_c03_001E;
run;

/*	Health data from ACS table ACSST5Y2018.S2704											*/
data data.acshealth1;
	set data.acshealth;
	keep geo_id name s2704_c03_026e; /*	percent covered with public insurance alone			*/
run;

/*	Place of birth data from ACS table ACSST5Y2018.S0501									*/

data data.acsnativity1;
	set data.acsnativity;
	keep nonnative zip_code_tabulation_area S0501_C01_001E S0501_C03_001E; /* Total population and Non-native born Population */
	nonnative = S0501_C03_001E/S0501_C01_001E;
run;

/*	Occupation data from ACS table ACSST5Y2018.S2401										*/
data data.acsoccupation1;
	set data.acsoccupation;
	keep service geo_id name S2401_C01_001E S2401_C01_018E; /* Population above 16y employed and pop. working in service */
	service = S2401_C01_018E/S2401_C01_001E;
run;

/*	Data for Median Income and Percent_under65_uninsured from Stephanie's data source		*/
data data.acsother1;
	format median_inc 8.2 zcta $7.;
	set data.acsother;
	keep zcta median_inc per_under65_uninsured;
	zcta = put(name,z5. -L);
	median_inc = input(compress(hh_median_inc,"$,"),8.2);
run;

/*	Housing data from ACS table ACSDT5Y2018.B25014											*/
data data.acshousing1;
	format zcta $7.  occperrm 8.3;
	set data.acshousing;
	zcta = put(zip_code_tabulation_area,z5. -L);
	occperrm = DP04_0079PE/100;
	keep zcta occperrm;
run;

	


/*		Set up datasets for merging.															*/
data data.acsrace1;
	format 
	DP05_0077PE_1 DP05_0078PE_1 DP05_0079PE_1 DP05_0080PE_1 DP05_0071PE_1 8.3
	zcta $7.
	;
	set data.acsrace1;
	DP05_0077PE_1= input(DP05_0077PE, 8.1)/100;
	DP05_0078PE_1= input(DP05_0078PE, 8.1)/100;
	DP05_0079PE_1= input(DP05_0079PE, 8.1)/100;
	DP05_0080PE_1= input(DP05_0080PE, 8.1)/100;
	DP05_0071PE_1= input(DP05_0071PE, 8.1)/100;
	zcta = substr(name,max(1,length(name)-4));

run;

data data.acspov1;
	format 
	S1701_c03_001E_1 8.3
	zcta $7.
	;
	set data.acspov1;
	S1701_c03_001E_1= input(S1701_c03_001E, 8.1)/100;
	zcta = substr(name,max(1,length(name)-4));
run;

data data.acshealth1;
	format 
	s2704_c03_026e_1 8.3
	zcta $7.
	;
	set data.acshealth1;
	s2704_c03_026e_1= input(s2704_c03_026e, 8.1)/100;
	zcta = substr(name,max(1,length(name)-4));
run;

data data.acsoccupation1;
	format 	zcta $7.;
	set data.acsoccupation1;
	zcta = substr(name,max(1,length(name)-4));
run;

data data.acsnativity1;
	format 	zcta $7.;
	set data.acsnativity1;
	zcta = put(input(zip_code_tabulation_area,best12.),z5.);
run;

/*	Frequency by hospital and zip code, collapsing frequency by week							*/
proc freq data=data.er_zip1;
table hospital*zcta/out=erfreq;
weight total_ed_visits;
run;

/*	Sort datasets by zcta for merging															*/
proc sort data=erfreq;
	by zcta;
run;
proc sort data=data.acsrace1;
	by zcta;
run;
proc sort data=data.acspov1;
	by zcta;
run;

proc sort data=data.acshealth1;
	by zcta;
run;

proc sort data=data.acsoccupation1;
	by zcta;
run;

proc sort data=data.acsnativity1;
	by zcta;
run;

proc sort data=data.acsother1;
	by zcta;
run;

proc sort data=data.acshousing1;
	by zcta;
run;

/*	Merge data by zcta, restricting to data present in ER Visit data							*/
/*	Multiply ER Visit frequency by proportion by zcta of variables of interest to obtain expected value		*/

data data.hospital;
	merge erfreq (in=b) data.acsrace1 (in=a) data.acspov1 (keep=zcta S1701_c03_001E_1) data.acshealth1 data.acshousing1 (in=c) data.acsnativity1 (keep=zcta nonnative) data.acsoccupation1 (keep=zcta service);
	by zcta;
	if a and b and c;
	exp_white = count*dp05_0077PE_1;
	exp_black = count*dp05_0078PE_1;
	exp_native = count*dp05_0079PE_1;
	exp_api = count*dp05_0080PE_1;
	exp_latino = count*dp05_0071PE_1;
	exp_pov = count*S1701_c03_001E_1;
	exp_pubins = count*s2704_c03_026e_1;
	exp_service = count*service;
	exp_nonnative = count*nonnative;
	exp_occperrm = count*occperrm;
run;

/*	Replace all empty cells with zeros															*/
proc stdize data=data.hospital out=data.hospital reponly missing=0;
run;

/*	Merge Stephanie's data (as this data does not have all zip codes in the US).				*/
data data.hospital_1;
	format zcta $7.;
	merge data.hospital data.acsother1;
	by zcta;
	if per_under65_uninsured NE . then do;
		exp_medianinc = median_inc*count;
		exp_per_under65_uninsured = per_under65_uninsured*count;
	end;
	if zcta NE .;
	if exp_occperrm < 0 then exp_occperrm = 0;
run;

/*	Merge resulting dataset with hospital names and FID											*/
proc sort data=data.hospital_1;
	by hospital;
run;

proc sort data=data.Name_list;
	by hospital;
run;

data data.hospital_2;
	merge data.Name_list (in=a) data.hospital_1 (in=b);
	by hospital;
	if b;
run;

/*	Collapse dataset by hospital FID, and calculated expected percentage of total population expected for each variable type	*/
data data.hosp_expectedvalue;
	set data.hospital_2;
	format exp_white_1 exp_black_1 exp_native_1 exp_api_1 exp_total_inc 
			exp_latino_1 exp_pov_1 exp_pubins_1 exp_service_1 exp_medianinc_1 
			exp_per_under65_uninsured_1 exp_nonnative_1 exp_occperrm_1 8.3;
	retain exp_white_1 exp_black_1 exp_native_1 exp_api_1 exp_latino_1 exp_pov_1 
			exp_pubins_1 exp_total exp_service_1 exp_nonnative_1 exp_medianinc_1 
			exp_per_under65_uninsured_1 exp_occperrm_1 exp_total_inc;
	by hospital;
	if first.hospital then do;
		exp_white_1 = 0;
		exp_black_1 = 0;
		exp_native_1 = 0;
		exp_api_1 = 0;
		exp_latino_1 = 0;
		exp_pov_1 = 0;
		exp_total = 0;
		exp_pubins_1 = 0;
		exp_service_1 = 0;
		exp_nonnative_1 = 0;
		exp_medianinc_1 = 0;
		exp_per_under65_uninsured_1 = 0;
		exp_total_inc = 0;
		exp_occperrm_1 = 0;
	end;
	if median_inc NE . then do;
		exp_medianinc_1 = exp_medianinc_1+exp_medianinc;
		exp_per_under65_uninsured_1 = exp_per_under65_uninsured_1+exp_per_under65_uninsured;
		exp_total_inc = exp_total_inc+count;
	end;
	exp_white_1 = exp_white_1 + exp_white;
	exp_black_1 = exp_black_1 + exp_black;
	exp_native_1 = exp_native_1 + exp_native;
	exp_api_1 = exp_api_1 + exp_api;
	exp_latino_1 = exp_latino_1 + exp_latino;
	exp_pov_1 = exp_pov_1 + exp_pov;
	exp_nonwhite = sum(exp_black_1,exp_native_1,exp_api_1,exp_latino_1);
	exp_pubins_1 = exp_pubins_1 + exp_pubins;
	exp_service_1 = exp_service_1 + exp_service;
	exp_nonnative_1 = exp_nonnative_1 + exp_nonnative;
	exp_occperrm_1 = exp_occperrm_1 + exp_occperrm;

	exp_total= exp_total+count;
	
	per_white = exp_white_1/exp_total;
	per_black = exp_black_1/exp_total;
	per_native = exp_native_1/exp_total;
	per_api = exp_api_1/exp_total;
	per_latino = exp_latino_1/exp_total;
	per_nonwhite = 1-per_white;

	per_pov = exp_pov_1/exp_total;

	per_pubins =exp_pubins_1/exp_total;

	per_service_1 = exp_service_1/EXP_TOTAL;

	per_nonnative_1 = exp_nonnative_1/exp_total;

	per_occperrm_1 = exp_occperrm_1/exp_total;

	avg_medianinc = exp_medianinc_1/exp_total_inc;
	per_per_under65_uninsured = exp_per_under65_uninsured_1/exp_total_inc;
	if GYNHA NE "Suppress";
	if last.hospital then output;

	keep NYS_Facility_ID GYNHA hospital exp_white_1 exp_black_1 exp_native_1 exp_api_1 exp_total_inc exp_latino_1 exp_pov_1 exp_occperrm_1 exp_pubins_1 exp_service_1 exp_per_under65_uninsured_1 exp_nonnative_1
		exp_total exp_nonwhite per_white per_black	per_native	per_api	per_latino	per_nonwhite per_occperrm_1 per_pov per_pubins per_service_1 per_nonnative_1 avg_medianinc per_per_under65_uninsured;

	
run;


/* Correlation between variables */
proc corr data = data.hosp_expectedvalue plots=matrix;
	var per_nonwhite avg_medianinc per_per_under65_uninsured per_occperrm_1 per_nonnative_1;
run;
