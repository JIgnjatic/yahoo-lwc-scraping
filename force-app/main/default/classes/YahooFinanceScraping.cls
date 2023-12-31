public class YahooFinanceScraping {

    //we have 2 givenDate params since yahoo historical requires 2 time points
    // the second param is +1 day due to Yahoo not rendering if they are the same
    @AuraEnabled
    public static YahooFinanceHTMLWrapper scrapeHTML(String ticker, String givenDateMiliseconds, String givenDateMilisecondsPlusOneDay,
                                                    String previousWorkDayMiliseconds,String previousCloseDateMilisecondsPlusOneDay) {
        List<YahooFinanceHTMLWrapper> yahooTickerWrapperList = new List<YahooFinanceHTMLWrapper>();
    
        YahooFinanceHTMLWrapper yfw = YahooFinanceScrapingHelper.fetchStockData(ticker, givenDateMiliseconds, givenDateMilisecondsPlusOneDay,
                                                                                previousWorkDayMiliseconds, previousCloseDateMilisecondsPlusOneDay);
        yfw.ticker = ticker;
       
        return yfw;
    }

    //we return the ID of the job so we can query it and see the live status on the front end
    @AuraEnabled 
    public static ID scrapeHTMLAsync(String ticker, String givenDateMiliseconds, String givenDateMilisecondsPlusOneDay, String previousWorkDayMiliseconds,
                                    String previousWorkDayMilisecondsPlusOneDay) {
        
        YahooFinanceScrapeQueueable job = new YahooFinanceScrapeQueueable(ticker,givenDateMiliseconds,givenDateMilisecondsPlusOneDay,previousWorkDayMiliseconds,
                                                                            previousWorkDayMilisecondsPlusOneDay);
        return System.enqueueJob(job);
    }
        

    @AuraEnabled
    public static List<Stock_Data__c> verifyDuplicates(List<String> tickers, String givenDateStr){
        try {
            
            Date givenDate = Date.valueOf(givenDateStr);
            
            List<Stock_Data__c> stockData = YahooFinanceScrapingDAO.findScrapedData(tickers,givenDate);
            return stockData;
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
   

    @AuraEnabled
    public static List<YahooLWCResponse> insertStockData(String stockDataList){
        
        List<YahooLWCResponse> ywrList = (List<YahooLWCResponse>) JSON.deserialize(stockDataList, List<YahooLWCResponse>.class);
        List<Stock_Data__c> stockList = new List<Stock_Data__c>();

        for(YahooLWCResponse ywr : ywrList){

            Stock_Data__c sd = new Stock_Data__c();
            sd.Name = ywr.ticker + ' ' + ywr.givenDate;
            sd.Ticker_Symbol__c = ywr.ticker;
            sd.Date__c = Date.valueOf(ywr.givenDate);
            sd.Open_Price__c = Decimal.valueOf(ywr.openPrice);
            sd.Close_Price__c = Decimal.valueOf(ywr.closePrice);
            sd.Market_Cap__c = String.valueOf(ywr.marketCap);
            sd.Employee_Number__c = ywr.employeeNumber;
            sd.Company_Address__c = ywr.companyAddress;
            sd.Industry__c = ywr.industry;

            stockList.add(sd);
        }

        try {
            Database.SaveResult[] results = Database.insert(stockList, false);            

            //we use the same wrapper to send the info back
            return addInsertResultsToWrapper(results, ywrList);
        } catch (Exception e) {
            System.debug('Failed to insert stock data. Error: ' + e.getMessage());
            throw new AuraHandledException('Failed to insert stock data. Error: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static List<AsyncApexJob> getJobsViaIDs(List<String> jobIDs){
        try {
            List<AsyncApexJob> jobs = [SELECT ID, Status, ExtendedStatus, CompletedDate FROM AsyncApexJob WHERE ID IN :jobIDs];
            return jobs;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }


    /////////
    //helper methods
    /////////

    //creates a YahooLWCResponse list from the results list to return to LWC (because SaveResult list cannot be returned to LWC)
    @TestVisible
    private static List<YahooLWCResponse> addInsertResultsToWrapper(List<Database.SaveResult> results, List<YahooLWCResponse> yahooLWCResponses ){

        List<YahooLWCResponse> ylrList = new List<YahooLWCResponse>(yahooLWCResponses);

        for(Integer i=0; i<results.size(); i++){
            Database.SaveResult sr = results[i];
            if(sr.isSuccess()){
                ylrList[i].success = true;
                ylrList[i].id = sr.getId();
            }else {
                Database.Error err = sr.getErrors()[0];
                ylrList[i].success = false;
                ylrList[i].errorMessage = err.getMessage();
            }
        }

        return ylrList;
    }


    
    public class YahooLWCResponse{
        @AuraEnabled
        public String ticker;
        @AuraEnabled
        public String givenDate;
        @AuraEnabled
        public String openPrice;
        @AuraEnabled
        public String closePrice;
        @AuraEnabled
        public String previousClosePrice;
        @AuraEnabled
        public String marketCap;
        @AuraEnabled
        public String employeeNumber;
        @AuraEnabled
        public String companyAddress;
        @AuraEnabled
        public String industry;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String id;
        @AuraEnabled 
        public Boolean success;
        @AuraEnabled
        public String errorMessage;
        @AuraEnabled
        public String yearFounded;
    }


    public class YahooFinanceHTMLWrapper {
        @AuraEnabled 
        public String ticker;
        @AuraEnabled
        public String stockData; 
        @AuraEnabled
        public String previousCloseDayStock;
        @AuraEnabled
        public String companyInfo; 
        @AuraEnabled
        public String marketCap; 
    }

}