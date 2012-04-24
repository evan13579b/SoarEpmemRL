4/23/2012

implemented model as discussed in class today.  Line 56 can be used to toggel between the two modes

- mode 1 "(<a1> ^current eat-food ^next think-food)"
   agent will eat 100 meals, with 10 doctors visits.  
   then will use epmem to replay these 100 moves with feedback each turn (esentailly doctor visit every turn)
   then agent will switch to eating with feedback each turn

- mode 2 "(<a1> ^current eat-food ^next eat-food2)"
   agent will eat 100 meals, with 10 doctors visits.  
   then agent will switch to eating with feedback each turn



Also there are two initial results files showing that the agent learns quicker/dies slower when using epmem.

