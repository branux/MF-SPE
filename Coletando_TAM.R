#pacotes necess�rios
library(RSelenium)
library(xlsx)
library(stringr)
setwd("C:\\Users\\44226842804\\Documents\\Rproject\\Passagens") #as coletas ser�o salvas aqui

#ligando o web-driver
checkForServer()
startServer()
mybrowser <- remoteDriver()
system("java -jar selenium-server-standalone-2.53.0.jar", wait = FALSE)
#� necess�rio ter o selenium standalone no wd.
#Voc� pode fazer o download do standalone aqui: http://www.seleniumhq.org/download/
#Obs: � preciso ter o java instalado no computador
#se der erro, coloque o selenium-server-standalone-2.53.0 no wd e abra manualemnte clicando nele.

#Fun��o que pega os dados brutos dos voos diretos e retorna uma lista com pre�os e a taxa
getDadosTAM <- function(origem, dataIda, destino, dataVolta){
    #site
    TAM <- "http://book.tam.com.br/TAM/dyn/air/"
    
    mybrowser$maxWindowSize(winHand = "current")
    #indo na TAM
    mybrowser$navigate(TAM)
    OrigemT <- mybrowser$findElement(using = 'css selector', "#search_from" )
    DestinoT <- mybrowser$findElement(using = 'css selector', "#search_to")
    dataSaidaT <- mybrowser$findElement(using = 'css selector', "#search_outbound_date")
    dataVoltaT <- mybrowser$findElement(using = 'css selector', "#search_inbound_date" )
    botaoIrT <- mybrowser$findElement(using = 'css selector', "#onlineSearchSubmitButton")
    
    #pesquisando viagem
    OrigemT$clearElement()
    OrigemT$sendKeysToElement(list(origem)) #escolhendo origem
    
    DestinoT$clearElement()
    DestinoT$sendKeysToElement(list(destino)) #escolhendo destino
    
    dataSaidaT$clearElement()
    dataSaidaT$sendKeysToElement(list(dataIda)) #escolhendo data de sa�da
    
    dataVoltaT$clearElement()
    dataVoltaT$sendKeysToElement(list(dataVolta)) #escolhendo data de volta
    
    botaoIrT$clickElement() #executando a pesquisa
    
    #recolhendo textos da tabela de voos diretos
    ida <- mybrowser$findElements(using = 'css selector', "#outbound_list_flight > tbody") #pega a tabela de ida
    ida <- unlist(ida[[1]]$getElementText()) #pega o texto da tabela de ida
    volta <- mybrowser$findElements(using = 'css selector', "#inbound_list_flight > tbody") #pega a tablea de volta
    volta <- unlist(volta[[1]]$getElementText()) #pega o texto da tabela de volta
    idavolta <- paste(ida, volta, sep = "____VOLTA____") #junta a ida com a volta
    ElementTaxa <-mybrowser$findElement(using = 'css selector', "dd.boxb") #pega  a taxa
    taxa <- ElementTaxa$getElementText()[[1]] #pega o texto bruto da taxa
    taxa <- str_extract(taxa, "[0-9][0-9],[0-9][0-9]") #limpa o texto da taxa
    
    return(list(idavolta, taxa))
}

#Pega os pre�os dos voos diretos
getTamDirectPrice <- function(textobruto){
    linhas <- strsplit(textobruto,
             split = "[0-9][0-9]:[0-9][0-9] [A-Z][A-Z][A-Z] [0-9][0-9]:[0-9][0-9] [A-Z][A-Z][A-Z]")[[1]][-1] #quebra em linhas onde houver o padr�o HORA AEROPORTO HORA AEROPORTO 
    linhasDiretas <- linhas[-(grep("conex�o|Escala|Dura��o total da viagem", linhas))] #Exclui linhas com "conex�o" ou "Escalas" ou "Dura��o total da viagem"
    precoBruto <- "\n([0-9]\\.)?[0-9][0-9][0-9](,[0-9][0-9])?" #padr�o dos pre�os brutos em metacaracteres
    precosBrutos <- unlist(str_extract_all(linhasDiretas, precoBruto)) #limpa os pre�os um pouco
    preco <- "([0-9]\\.)?[0-9][0-9][0-9](,[0-9][0-9])?" #padr�o do pre�o limpo em metacaracteres
    precos <- unlist(str_extract_all(precosBrutos, preco)) #limpa os pre�os e os guarda
    return(precos) #retorna os pre�os limpos
}

#Coleta uma cidade
coletar <- function(cidade, ida, volta, n = 60){
    tabela <- rep.int(c("Preco"), n) #inicia a tabela
    cnames <- c("1") #vetor de nome das colunas
    for(origem in cidade[[2]]){ #itera pelas v�rias origens
        dados <- getDadosTAM(origem = origem, dataIda = ida, dataVolta = volta, destino = cidade[[1]]) #pega os dados da viagem
        precos <- getTamDirectPrice(dados[[1]]) #pega os pre�os limpos dos voos diretos
        taxa <- dados[[2]] #pega a taxa
        if(length(precos)>n){
            stop("Tamanho dos custos maior que a tabela!!! Use uma tabela (n) maior.")
        } #se a tabela iciiada for menor que o tamalho do vetor de �pre�os, retorna um erro
        if(!is.null(precos)){ #se houver pre�os de voos diretos
            
            length(precos) <- n #amplia o vetor de pre�os para o tamanho da tabela
            precos <- gsub("\\.", "", precos) #tira o ponto do milhar
            tabela <- cbind(tabela, precos) #junta o vetor de pre�os na tabela
            cnames <- c(cnames, origem) #junta o nome da origem ao vetor de nomes das colunas
            
            length(taxa) <- n #amplia o vetor de taxa para o tamanho da tabela
            tabela <- cbind(tabela, taxa) #junta a taxa na tabela da coleta
            cnames <- c(cnames, paste(origem, "Taxa", sep ="_" )) #junta o nome da origem com "Taxa" e adiciona ao vetor de nomes das colunas
            
        }
        if(is.null(precos)){ #caso n�o exita pre�o de voos diretos
            precos <- "Sem VD"
            length(precos) <- n
            tabela <- cbind(tabela, precos)
            cnames <- c(cnames , origem)
        } 
    }
    colnames(tabela) <- cnames #nomeia as colunas com o vetor de nomes de colunas criado acima
    return(as.data.frame(tabela))
}

coletarTudo <- function(cidades, ida, volta, n = 60){
    mybrowser$open() #abre o browser
    i <-  1
    wb <- createWorkbook() #cria um arquivo excel
    while(i <= length(cidades)){ #itera pelas cidades
        tabela <- coletar(cidades[[i]],ida,volta,n) #itera pelas origens de uma cidade e retorna os pre�os
        sheet <- createSheet(wb, sheetName = cidades[[i]][[1]]) #cria uma aba no excel e nomia com a cidade de coleta
        addDataFrame(tabela, sheet, col.names = T, row.names = F) #adiciona os pre�os acima na aba do excel
        i <- i+1
    }
    return(wb) #retorna o arquivo excel
}



#-------------------------------------------------------------------------------------------------------------------------
#fazendo a coleta

#As cidades cont�m o nome como primeiro elemento e um vetor de origens da viagem como segundo elemento

#Matheus
salvador <- list("SSA", c("GIG","CNF", "REC", "GRU", "BSB", "Fortaleza", "VIX"))
natal <- list("Natal", c("GIG", "GRU", "BSB", "Fortaleza", "SSA"))
manaus <- list("MAO", c("GIG", "GRU", "BSB", "Belem"))
matheus <- list(salvador, natal, manaus)

#Luiz
curitiba <- list("CWB", c("GIG", "POA","GRU", "BSB"))
florianopolis <- list("FLN", c("GIG", "POA", "GRU", "BSB"))
fortaleza <- list("Fortaleza", c("GIG", "REC", "GRU", "BSB", "Belem", "SSA"))
luiz <- list(curitiba, florianopolis, fortaleza)

#Odete
rio <- list("GIG", c("POA", "BHZ", "REC","GRU", "BSB", "Belem", "Fortaleza","CWB", "SSA", "GYN", "VIX", "CGR"))
odete <- list(rio)


#luiz
saopaulo <- list("GRU", c("GIG", "POA", "CNF", "REC", "BSB", "Belem", "Fortaleza", "CWB", "SSA", "GYN", "VIX", "CGR"))
vicente <- list(saopaulo)

#datas da coleta
ida <- "27/08/2016"
volta <- "04/09/2016"



start.time <- Sys.time() #inicia cont�gem do tempo

wb1 <- coletarTudo(luiz, ida, volta, 60) #cria o documento excel da pesquisa
saveWorkbook(wb1, "coletaTAMLuiz.xlsx") #exporta o documento excel para fora do R, com o nome especificado e no wd

wb2 <- coletarTudo(matheus, ida, volta, 60) #cria o documento excel da pesquisa
saveWorkbook(wb2, "coletaTAMMatheus.xlsx") #exporta o documento excel para fora do R, com o nome especificado e no wd

wb3 <- coletarTudo(odete, ida, volta, 60) #cria o documento excel da pesquisa
saveWorkbook(wb3, "coletaTAMOdete.xlsx") #exporta o documento excel para fora do R, com o nome especificado e no wd

wb4 <- coletarTudo(vicente, ida, volta, 60) #cria o documento excel da pesquisa
saveWorkbook(wb4, "coletaTAMVicente.xlsx") #exporta o documento excel para fora do R, com o nome especificado e no wd

end.time <- Sys.time() #termina cont�gem do tempo
time.taken <- end.time - start.time
time.taken #mostra em quanto tempo foi feita a pesquisa.
