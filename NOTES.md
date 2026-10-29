Meet notes:
resend is an email service , cloud front , RDS for database(free tier),no load balancer,JWt for identifying the user
invite will contain a signed message or secret
FrontEnd -> S3 -> cloudfront
Api -> EC2 or EB
Database -> RDS free tier POSTGRES or Maria DB

Technical Dev notes:
set a delay timer after user saves notes then async send active workspace info to database after save delay expires

on workspace switch prompt user to save or discard changes

add lastMod field to Note and Workspace tables to use as metrics to update database note and workspace info [R?]

event links expire after min(currentDate- eventStartDate, 30) days, and event links are singleUse tokens they expire once used by a user

Additional settings features:
- American date format : MM/DD/YYYY
- Another format: YYYY/MM/DD
- instead of name of the month we put the number of the month
- we can add the user to customize the start of the week (Instead sunday that can i put any day they like)
- we can