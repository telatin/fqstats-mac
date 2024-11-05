//
//  UTTypes.swift
//  FqTest
//
//  Created by Andrea Telatin (QIB) on 05/11/2024.
//

import UniformTypeIdentifiers

extension UTType {
    static var fasta: UTType {
        UTType(importedAs: "com.bioinformatics.fasta")
    }
    
    static var fastq: UTType {
        UTType(importedAs: "com.bioinformatics.fastq")
    }
    
    // Also add gzipped versions
    static var gzippedFasta: UTType {
        UTType(importedAs: "com.bioinformatics.fasta.gz")
    }
    
    static var gzippedFastq: UTType {
        UTType(importedAs: "com.bioinformatics.fastq.gz")
    }
}
