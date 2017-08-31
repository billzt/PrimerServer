# PrimerServer
a high-throughput primer design and specificity-checking platform

## Wiki
Please see the [wiki](https://github.com/billzt/PrimerServer/wiki) for this repository

## Pre-Print
Zhu T, Liang CZ, Meng ZG, Li YY, Wu YY, Guo SD* and Zhang R* (2017). PrimerServer: a high-throughput primer design and specificity-checking platform. bioRxiv 181941

## Description
PrimerServer was proposed to design genome-wide specific PCR primers. It uses candidate primers produced by Primer3, uses BLAST and nucleotide thermodynamics to search for possible amplicons and filters out specific primers for each site. By using multiple threads, it runs very fast, ~0.4s per site in our case study for more than 10000 sites. 
