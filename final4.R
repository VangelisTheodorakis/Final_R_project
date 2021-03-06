rm(list=ls())

#diale3i lagani
#http://bioinformatics-core-shared-training.github.io/cruk-bioinf-sschool/Day3/rnaSeq_DE.pdf

#Our source of label vector:
#https://trace.ncbi.nlm.nih.gov/Traces/study/?acc=SRP018008&go=go
#https://trace.ncbi.nlm.nih.gov/Traces/sra/?study=SRP018008

#Define a function for loading packages
load_ = function(pkg, bioC=T) {
	#character.only has to be set to True in order for require() or library() to realize it's dealing with a variable
	if(!require(pkg, character.only=T, quietly = T)) {
		if(bioC){
			source(file = "http://bioconductor.org/biocLite.R")
			biocLite(pkg, dependencies=T)
		} else {
			install.packages(pkg)
		}
	}
	library(pkg, character.only=T)
}

#Installing and loading the required packages
load_("codetools", bioC=F)
load_("glue",bioC=F)
load_("doRNG", bioC=F)
load_("recount")
load_("DESeq2")
load_("edgeR")
load_('plotly', bioC=F)
load_('corrplot', bioC=F)
load_("AnnotationDbi")
load_("org.Hs.eg.db")
load_("clusterProfiler")
load_('biomaRt')



#fores pou 8a tre3ei to bootstrap
n<-1

#####################################################
#  				Obtaining the Dataset   			#
#####################################################

#project of interest
project_id <- 'SRP018008';

# Download the gene-level RangedSummarizedExperiment data
download_study(project_id)

# Load the object rse_gene
load(file.path(project_id, 'rse_gene.Rdata'))

#finding the labels we are missing
sra_run_table<-read.table("SraRunTable.csv",header = TRUE,sep="\t")
# We get the columns for sample id and sample classes (cancer / normal)
sra_run_subset <- sra_run_table[,c(11,12)]

#We realised there are 2 distinct notations, so we will keep a color vector for samples
#corresponding to different notations. It may be useful.
color_notations<-apply(sra_run_subset[2],2, function(x) sub(".*_.*","green",x))
color_notations<-apply(color_notations,2, function(x) sub(".*-.*[NT]","cyan",x))

# Using a regular expression we remove the prefix before the cancer/normal
# The first condition for the data are to be B123_Normal or B123_Cancer so we just erase the prefix

sra_run_subset[2]<-apply(sra_run_subset[2],2, function(x) sub(".*_","",x))

# On the other hand e.g B123-12N (for normal) or B123-12T (for tumor), we replace the whole value
sra_run_subset[2]<-apply(sra_run_subset[2],2, function(x) sub(".*-.*N","Normal",x))
sra_run_subset[2]<-apply(sra_run_subset[2],2, function(x) sub(".*-.*T","Cancer",x))

# Get the samples from the summary experiment and put them in a dataframe
transcripts<- as.data.frame(sort(rse_gene$sample))

sra_run_subset<- sra_run_subset[order(sra_run_subset$SRA_Sample_s),]

# Rename the column name
colnames(transcripts)[1]<-"RSA_Samples"

#extracting the count data
count_data <- assay(rse_gene)

#we have the label vector, we know need to sort it corresponding to the recount data
characteristics_vec<-c()
labels<-c()
for (i in 1:length(rse_gene$sample)){
	#for each column downloaded from recount
	name<-rse_gene$sample[i]
	for (j in 1:length(sra_run_subset$SRA_Sample_s)){
		#match the one in SRA table and keep the label
		name2<-sra_run_subset$SRA_Sample_s[j]
		if(name==name2){
			labels[i]<-sra_run_subset$Sample_Name_s[j]
		}
	}
}

labels

#####################################################
#  				Quality Check 			   			#
#####################################################


cpm.tmm <- function(counts, groups=NA){
    require(edgeR)
    if(is.na(groups)){
        d<-DGEList(counts=counts)
    }
    else{
        d<-DGEList(counts=counts, group=groups)
    }
    d <- calcNormFactors(d, method="TMM")
    return(cpm(d, normalized.lib.sizes=TRUE))
}

count_data<-cpm.tmm(count_data,labels)

### Plotting ###

color = labels
color[color=='Cancer'] = 'red'
color[color=='Normal'] = 'blue'
png("BoxPlot1.png")
boxplot(count_data, xlab = "observations", ylab = "counts", col = color, outline = FALSE)
legend("topright", c('Normal','Cancer'),fill=c('blue','red'))
dev.off()

#Many counts are close to zero and provide skewed boxplots
#remove the genes that have very small counts
#we choose to remove those that appear less than 50 times the number of samples (93). Which means 50 per sample on average.
toKeep <- apply(count_data, 1, sum) > 50 * dim(count_data)[2];
count_data <- count_data[toKeep, ];
dim(count_data)

png("BoxPlot2.png")
boxplot(count_data, xlab = "observations", ylab = "counts", col = color, outline = FALSE)
legend("topright", c('Normal','Cancer'),fill=c('blue','red'))
dev.off()


#Visualize based on the different notations. Maybe they correspond to different studies.
png("BoxPlotNotations.png")
boxplot(count_data, xlab = "observations", ylab = "counts", col = color_notations, outline = FALSE)
legend("topright", c('Notation_1','Notation_2'),fill=c('green','cyan'))
dev.off()



#The shift in the dataset is caused by a batch effect, so we get rid of the corresponding data
count_data<-count_data[,1:75]
labels<-labels[1:75]

png("BoxPlot3.png")
boxplot(count_data, xlab = "observations", ylab = "counts", col = color, outline = FALSE)
legend("topright", c('Normal','Cancer'),fill=c('blue','red'))
dev.off()

#====================================================
#====================================================
#====================================================

#antwnis 19/6/17
categories_vec <- c()
for(i in 1:n){

	if(n>1){
	print(i)
	#des posoi einai oi cancer kai oi normal
	cancer_patients<-length(which(labels=="Cancer"))
	normal_patients<-length(which(labels=="Normal"))

	#krata ta indexes ston count data pou einai to ka8e group
	cancer_col_indexes <- which(labels=="Cancer")
	normal_col_indexes <- which(labels=="Normal")

	#xwrise ta group meta3i tous se 2 mikrotera
	normal_data<- count_data[,normal_col_indexes]
	dim(normal_data)

	cancer_data<- count_data[,cancer_col_indexes]
	dim(cancer_data)

	#kataskeuase nea indexes pou 8a xrisimopoih8oun me replacement
	cancer_new_indexes<-sample(cancer_patients, cancer_patients, replace = TRUE, prob = NULL)
	normal_new_indexes<-sample(normal_patients, normal_patients, replace = TRUE, prob = NULL)

	#kataskeauase ta permutation tou ka8e group analoga me ta indexes
	final_normal_data<-normal_data[,normal_new_indexes]
	final_cancer_data<-cancer_data[,cancer_new_indexes]

	#kane bind ta nea group se ena megalo
	count_data<-cbind(final_normal_data,final_cancer_data)

	#to charactericsd_vec2 einai pleon me tin seira ola ta normal mazi ola ta cancer mazi giati
	#etsi ta kaname sto cbind
	labels<-c(rep("Normal",normal_patients),rep("Cancer",cancer_patients))

	#sbise ta colnames giati twra exoume epanotopo8etisi kai den sineragazetai to DGElist
	colnames(count_data) <- NULL
	}

#antwnis 19/6/17

#prwto link
#https://web.stanford.edu/class/bios221/labs/rnaseq/lab_4_rnaseq.html

#object for edgeR

dgList <- DGEList(counts=count_data,genes=rownames(count_data), group=factor(labels))

#design matrix: (one hot encoding)
design.mat <- model.matrix(~ 0 + dgList$samples$group)
colnames(design.mat) <- levels(dgList$samples$group)

d2<-estimateDisp.DGEList(dgList,design.mat)

#trito link
#Compute genewise exact tests for differences in the means between two groups of negative-binomially distributed counts.
et <- exactTest(d2)
results_edgeR <- topTags(et, n = nrow(count_data), sort.by = "PValue")

#krata mono ta data
edger_table<-results_edgeR$table
#keep the differentially expressed genes with a significance lower than the Bonferroni cutoff
diff_genes<-edger_table[edger_table$PValue<0.05/nrow(edger_table),]
diff_genes_names<-diff_genes$genes

# we get rid of the dots that ruin the entrez id
diff_genes_names<-gsub("\\..*","",diff_genes_names)

universe_genes<-gsub("\\..*","",edger_table$genes)

###########################################################################

#Mapping from ensembl ID to entrez ID
mart <- useDataset("hsapiens_gene_ensembl", useMart("ensembl"))

G_list1 <- getBM(filters= "ensembl_gene_id", attributes= c("ensembl_gene_id",
"entrezgene", "description"),values=diff_genes_names,mart= mart)

G_list2 <- getBM(filters= "ensembl_gene_id", attributes= c("ensembl_gene_id",
"entrezgene", "description"),values=universe_genes,mart= mart)

entrez_diff_genes_names<-G_list1[,2]
entrez_diff_genes_names<-as.character(entrez_diff_genes_names[!is.na(entrez_diff_genes_names)])

universe_genes<-G_list2[,2]
universe_genes<-as.character(universe_genes[!is.na(universe_genes)])


ego <- enrichGO(gene          = entrez_diff_genes_names,
                universe      = universe_genes,
                OrgDb         = org.Hs.eg.db,
                ont           = "BP",
                pAdjustMethod = "fdr",
                pvalueCutoff  = 0.05,
                qvalueCutoff  = 0.05,
                minGSSize     = 15,
                maxGSSize     = 500,
                readable      = TRUE)
#

head(ego)[, 1:7]


filteredEgo <- gofilter(ego, level = 4);
dim(filteredEgo)

png("dotplot.png")
dotplot(filteredEgo)
dev.off()

categories_vec<-c(categories_vec,filteredEgo$ID)
}

if(n>1){

	filename<-paste("output",n,".txt",sep="")
	sink(filename)
	print (categories_vec)
	sink()

	filename<-paste("output",n,".txt",sep="")
	x<-scan(filename, character(), quote = "")

	#clean
	x <- x[nchar(x) > 7]

	#kane to dataframe me 1 column gia na einai to ena katw apo to allo
	a = data.frame("data"=x)

	#bres poso sixna emfanizetai to ka8e GO
	a<-as.data.frame(table(a))

	a<-a[order(-a$Freq),]

	#the majority of the genes are seen as differentially expressed at least once, this is due to the bootstrap and the
	#result should be interpreted as pure luck, and thus should be discarded
	a<-a[!(a$Freq==1),]

	png("barplot.png")
	hist(a$Freq,col="cyan",main="Results from bootstrap",ylab="Number of Gens", xlab="Frequency of importance",breaks=10)
	dev.off()

	temp<-a[a$Freq>=95,]
	temp2<-temp[,1]
}
