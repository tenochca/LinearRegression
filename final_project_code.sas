DATA gmc_price_infile;
INFILE "gmc_price.txt" delimiter='09'x FIRSTOBS=2;
INPUT Price Mileage Make$ Model$ Trim$ Type$ Cylinder Liter Doors Cruise Sound Leather;
RUN;
PROC PRINT;
RUN;

*checking frequencies of categporical variables;
PROC FREQ data=gmc_price_infile;
tables Make / NOPRINT OUT=FreqOut;
RUN;
PROC PRINT;
RUN;

PROC FREQ data=gmc_price_infile;
tables Model / NOPRINT OUT=FreqOut;
RUN;
PROC PRINT;
RUN;

PROC FREQ data=gmc_price_infile;
tables Type / NOPRINT OUT=FreqOut;
RUN;
PROC PRINT;
RUN;

*Making dummies--dropping model along with trim and type, dont need, too specific and too many dummies;
DATA gmc_new;
set gmc_price_infile;

*dummy variables for doors;
if Doors = 4 then d_doors = 1;
		else d_doors = 0;

*dummies for Type--Hatchbac is refernce level;
if Type = 'Converti' then Type_Converti = 1;
	  else Type_Converti = 0;
if Type = "Coupe" then Type_Coupe = 1;
	  else Type_Coupe = 0;
*if Type = "Hatchbac" then Type_Hatchbac = 1;
	  *else Type_Hatchbac = 0;
if Type = "Sedan" then Type_Sedan = 1;
	  else Type_Sedan = 0;
if Type = "Wagon" then Type_Wagon = 1;
	  else Type_Wagon = 0;

drop Type;
drop Trim;
drop Model;
drop Doors;
drop Make
RUN;
PROC PRINT data=gmc_new (obs=10);
RUN;

*Plots and graphs;
TITLE"Descriptives";
PROC MEANS mean min p25 p50 p75 max;
var Price Mileage Liter;
RUN;

*needs transformation;
TITLE"Histogram for Price";
PROC UNIVARIATE normal;
var Price;
Histogram / normal (mu=est sigma=est);
RUN;

TITLE"Histogram for Milage";
PROC UNIVARIATE normal;
var Mileage;
Histogram / normal (mu=est sigma=est);
RUN;


TITLE"Histogram for Liter";
PROC UNIVARIATE normal;
var Liter;
Histogram / normal (mu=est sigma=est);
RUN;

*log tranformation on PRICE;
TITLE"log transform";
DATA gmc_new;
set gmc_new;
lnPrice=log(Price);
drop Price
RUN;
PROC PRINT data=gmc_new (obs=5);
RUN;

*transformed price distribution;
TITLE"Histogram for lnPrice";
PROC UNIVARIATE normal;
var lnPrice;
Histogram / normal (mu=est sigma=est);
RUN;

*scatter matrix and corr matrix;
TITLE"Scatter Matrix";
PROC SGSCATTER;
MATRIX lnPrice Mileage Liter;
RUN;

TITLE"Corr Matrix";
PROC CORR;
var lnPrice Mileage Liter Cylinder Cruise Sound Leather Type_Converti Type_Coupe Type_Sedan Type_Wagon d_doors;
RUN;

*full model;
TITLE"Full Model";
PROC REG data = gmc_new;
model lnPrice = Mileage Liter Cruise Sound Leather Cylinder d_doors Type_Converti Type_Coupe Type_Sedan Type_Wagon/vif stb;
RUN;

*Cylinder and liter are colinear--dropping cylinder;
*d_doors and conflicts with the dummy variables for Type as coup already specifies a 2-door car--dropping d_doors;
TITLE"Dropping Cylinder and d_doors";
DATA gmc_new;
set gmc_new;
drop Cylinder;
drop d_doors
RUN;
PROC PRINT data=gmc_new (obs=5);
RUN;

*reruning full model after adjustments;
TITLE"Full Model v2";
PROC REG data = gmc_new;
model lnPrice = Mileage Liter Cruise Sound Leather Type_Converti Type_Coupe Type_Sedan Type_Wagon/r influence vif stb;
plot student.*predicted.;
plot student.*(Mileage Liter predicted.);
plot npp.*student.;
RUN;

*outlier removal;
DATA gmc_new;
set gmc_new;
if _n_ in (341, 342, 343, 344, 345, 346, 347, 348, 349, 350, 650) then delete;
RUN;

*rerunning model after removal of influencial points;
PROC REG data = gmc_new;
model lnPrice = Mileage Liter Cruise Sound Leather Type_Converti Type_Coupe Type_Sedan Type_Wagon/vif stb;
RUN;

*creating training and testing sets;
TITLE'selecting training and testing';
PROC SURVEYSELECT data = gmc_new out=xv_all seed=341820 samprate=0.80 outall;
RUN;

TITLE"Training set";
data gmc_train (where = (Selected =1));
set xv_all;
RUN;
PROC PRINT data=gmc_train (obs=10);
RUN;

TITLE"Testing set";
data gmc_test (where = (Selected =0));
set xv_all;
RUN;
PROC PRINT data=gmc_test (obs=10);
RUN;

*model selection procedure;
TITLE"Model Selection-backward selection";
PROC REG data = gmc_train;
model lnPrice = Mileage Liter Cruise Sound Leather Type_Converti Type_Coupe Type_Sedan Type_Wagon/selection=backward stb;
RUN;

TITLE"adj-r selection";
PROC REG data = gmc_train;
model lnPrice = Mileage Liter Cruise Sound Leather Type_Converti Type_Coupe Type_Sedan Type_Wagon/selection=adjrsq stb;
RUN;

TITLE"Final Model";
PROC REG data = gmc_train;
model lnPrice = Mileage Liter Cruise Leather Type_Converti Type_Sedan Type_Wagon / stb;
plot student.*predicted.;
plot student.*(Mileage Liter predicted.);
plot npp.*student.;
RUN;

*dropping coup and sound;
DATA gmc_train;
set gmc_train;
drop Type_Coup;
drop sound
RUN;

*computing 2 predictions based on final model;
TITLE"2 predictions based on the following datalines";
DATA pred;
input Mileage Liter Cruise Leather Type_Converti Type_Sedan Type_Wagon;
datalines;
34210 4.6 1 1 0 0 1
10023 3.8 1 0 1 0 0
;
PROC PRINT data=pred;
RUN;

TITLE"joining new dataset with current";
DATA prediction;
set pred gmc_train;
RUN;
PROC PRINT data=prediction (obs=5);
RUN;

PROC REG;
model lnPrice = Mileage Liter Cruise Leather Type_Converti Type_Sedan Type_Wagon / p clm cli;
RUN;

*Validation of the model--getting predictions for test set;
TITLE"Validation-Test set";
PROC REG data = gmc_test;
model lnPrice = Mileage Liter Cruise Leather Type_Converti Type_Sedan Type_Wagon;
output out=predict_test p=predicted_test;
RUN;
PROC PRINT;
RUN;

TITLE'Difference between observed and predicted in training';
DATA predict_sum;
set predict_test;
d=lnPrice-predicted_test; 
absd=abs(d);
RUN;

*computing predictive statistics;
TITLE'Training Performance';
PROC SUMMARY data=predict_sum;
var lnPrice Mileage Liter Cruise Leather Type_Converti Type_Sedan Type_Wagon;
output out=predict_test_stats std(d)=rmse mean(absd)=mae;
RUN;
PROC PRINT data = predict_test_stats;
TITLE'Validation statistics for model';
RUN;

PROC CORR data=predict_test;
var lnPrice predicted_test;
RUN;








