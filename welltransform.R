# A script to transform well data files into a properly readable format for adding to a PostgreSQL database. 
# It removes excess header lines and makes sure all levels are in cm units
# Then it adds a properly formatted datetime column. 


d<-dir()
fileName <- d[grep("11311045",d)[1]]
# The biggest problem I'm having here is getting the well name from somewhere. I could connect to the database using a library, but I still run into the problem of knowing what well is in the process... oi vey. 

# Opens the object. Working directory is assumed to be root. 
object <- read.csv(fileName, header=T, skip=5)

#converts inches to cm
inEntries<-grep("in",object[,4])
if (length(inEntries)> 0){
  object[inEntries,3]<-object[inEntries,3]*2.54
  object[inEntries,4]<-"cm      "
}

# Adds a formatted datetime column
object$date.time<-paste(object[,1], object[,2], sep=" ")
object$date.time<-as.POSIXct(object$date.time, format="%m/%d/%Y %H:%M", tz="EST")

write.table(object, file=paste("up_",fileName, sep=""))
