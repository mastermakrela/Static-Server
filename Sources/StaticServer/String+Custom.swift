//
//  String+Custom.swift
//
//
//  Created by Krzysztof Kostrzewa on 26/11/2020.
//

extension String {
    var containsDotDot: Bool {
        for idx in indices {
            if self[idx] == ".", idx < index(before: endIndex), self[index(after: idx)] == "." {
                return true
            }
        }
        return false
    }
}
