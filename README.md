Author: Massimo Re Ferre' (www.it20.info)

Please refer to these blog posts for insides and context re how to use the tool:

http://it20.info/2014/04/vchs-monitoring-and-capacity-management-101-the-theory

http://it20.info/2014/04/vchs-monitoring-and-capacity-management-101-the-practice 

The tool is an HTML/JS site to visualize CSV files. 

These CSV files are created using the Ruby (1.9.2) tool that you can find in the "CSV creator" folder.

Usage example: "ruby vDCmonitoring.rb 30 vDC1.csv". 

This will create a CSV file named vDC1.csv that describes the consumption characteristics of the virtual data center configured in the file config-vDCmonitoring.yml

You can then visualize the CSV file using the HTML application. 

This tool is based on the Raphael Linechart tool (https://github.com/n0nick/raphael-linechart). 

Credits:

Andrea Siviero, because he helped me with the HTML/JS hammering and, in doing so, he has demonstrated to have once again above-average patient.  

William Lam, because my ruby script hasn't been written from scratch (http://www.virtuallyghetto.com/2013/02/exploring-vcloud-api-using-ruby.html) and we all stand on the shoulders of giants

