/****************************************************************************************************/
/*	Code to Compare Imputed Racial and Makeup of Hospitals to Real World Racial Data				*/
/*																									*/
/*	Programmed By: Camille Chaustre McNally															*/
/*	Date: 05/09/2020																				*/
/*																									*/
/*	Description: Code compares imputed racial makeup from zip code imputation technique to			*/
/*		available self-identified racial data from hospital ER visits from similar timeframes.		*/
/*		Analysis done using simple linear regression between imputed and observed proportions. 		*/
/*		with imputed proportions as the predictor variable. Stepwise selection was used to			*/
/*		investigate whether other imputed characteristics (such as estimated median income) could 	*/
/*		improve the predictive power of these regressions.											*/
/****************************************************************************************************/

/*	Import the observed values of self-reported race in ER visits for available hospitals			*/
proc import datafile="R:\EmergencyEvents\2019_nCoV\IDT\Allocation Algorithms\ED Admission Numbers and Zip Codes\HSSB_data_request_allED.csv"
        out=data.HSSB_allED
        dbms=csv
        replace;
    

     getnames=yes;
run;

proc sort data=data.hssb_alled;
	by NYS_Facility_ID;
run;
/*	Create an aggregated count of each variable by hospital FID	*/
data data.hssb_alled_cum;
	set data.hssb_alled;
	by NYS_Facility_ID;
	format first_week last_week mmddyy10.;
	retain first_week total black_count hispanic_count nonwhite_count race_ava_count eth_ava_count race_eth_ava_count;
	if first.nys_facility_id then do;
		total = .;
		black_count=.; 
		hispanic_count=.; 
		nonwhite_count=.; 
		race_ava_count=.; 
		eth_ava_count=.; 
		race_eth_ava_count=.;
		first_week = weekending;
	end;
	if last.nys_facility_id then do;
		last_week = weekending;
	end;
 	total + total_ED_count;
	black_count + ED_Black_count;
	hispanic_count + ED_Hispanic_count; 
	nonwhite_count + ED_NonWhite_count; 
	race_ava_count + race_available_count; 
	eth_ava_count + ethnicity_available_count; 
	race_eth_ava_count + race_ethn_available_count;
if last.nys_facility_id then output;
keep first_week last_week NYS_Facility_ID gynha hospital total black_count hispanic_count nonwhite_count race_ava_count eth_ava_count race_eth_ava_count;
run;

/*	For hospitals with available counts of self identified black and hispanic visitors, create a proportion	*/
data data.hssb_alled_cum;
	set data.hssb_alled_cum;
	if black_count NE . then do;
		per_black = black_count/race_ava_count;
	end;
	if hispanic_count NE . then do;
		per_hispanic = hispanic_count/eth_ava_count;
	end;
run;

/*	Rename variables before merging for easier identification	*/
data data.hssb_alled_cum;
	set data.hssb_alled_cum;
	rename per_black = hssb_per_black
			per_hispanic = hssb_per_hispanic;
run;

proc sort datadata=data.hosp_expectedvalue;
	by NYS_Facility_ID;
run;
/*	Merge observed data with imputed dataset by FID	*/
data data.compare;
	merge 	data.hssb_alled_cum (keep= nys_facility_id hssb_per_black hssb_per_hispanic) 
			data.hosp_expectedvalue;
	by nys_facility_id;
run;

/*	Pearson correlations between observed and imputed racial demographics	*/
ods graphics on;
proc corr data = data.compare plots=matrix;
	var hssb_per_black per_black;
run;
proc corr data = data.compare plots=matrix;
	var hssb_per_hispanic per_latino;
run;
ods graphics off;

/*	Simple linear regression model between observed and imputed racial and ethnic demographics weighted by total number of observations in imputed model	*/
ods graphics on;
proc reg data=data.compare;
model hssb_per_black = per_black;
weight exp_total;
run;

proc reg data=data.compare;
model hssb_per_hispanic = per_latino;
weight exp_total;
run;

/*	Stepwise regression with imputed hospital demographics as potential explanatory variables. Weighted by total patients in imputed dataset	*/

proc reg data=data.compare;
model hssb_per_black = 	per_black /* Proportion imputed Black Patients */
						per_nonwhite /* Proportion imputed all non-white patients */
						per_pov /* Proportion imputed living below poverty line*/
						per_pubins /* Proportion imputed using public insurance */
						per_service_1 /* Proportion imputed working in service industry*/
						per_nonnative_1 /* Proportion imputed born outside the US */
						per_occperrm_1 /* Proportion living with > 1.5 occupants per room */
						per_per_under65_uninsured /*proportion under age 65 uninsured */
						/ include=1 selection=stepwise slentry=0.25 slstay=0.15 ;
weight exp_total; /* Weighted by total number of patients in imputation data */
run;

proc reg data=data.compare;
model hssb_per_hispanic = per_latino 						per_nonwhite /* Proportion imputed all non-white patients */
						per_pov /* Proportion imputed living below poverty line*/
						per_pubins /* Proportion imputed using public insurance */
						per_service_1 /* Proportion imputed working in service industry*/
						per_nonnative_1 /* Proportion imputed born outside the US */
						per_occperrm_1 /* Proportion living with > 1.5 occupants per room */
						per_per_under65_uninsured /*proportion under age 65 uninsured */
						/ include=1 selection=stepwise slentry=0.25 slstay=0.15 ;
weight exp_total; /* Weighted by total number of patients in imputation data */
run;

/*	Multivariate regression model for variables selected by stepwise regression for Latino/Hispanic predictive model weighted by total number of observations in imputed model	*/
proc reg data=data.compare;
model hssb_per_black = per_black;
model hssb_per_hispanic = per_latino per_service_1 per_per_under65_uninsured;
weight exp_total;
run;
