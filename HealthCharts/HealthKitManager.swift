//
//  HealthKitManager.swift
//  Holds class for handling HealthKit framework interactions
//
//  Created by André Amador on 12/10/2026.
//

import Foundation
import HealthKit


enum HKManagerError: Error {
    case healthDataUnavailable
    case invalidDateRange
}

class HealthKitManager {

    private let healthStore: HKHealthStore = HKHealthStore()

    /// Requests authorization to read the provided HealthKit data types.
    ///
    /// - Parameter types: The HealthKit data types the application wants to read.
    /// - Throws: `HKManagerError.healthDataUnavailable` if HealthKit
    ///   is unavailable on the device.
    /// - Important: Successful completion means the authorization request
    ///   finished. It does not prove the user granted read access.

    private func requestReadAuth(types: [HKObjectType]) async throws -> Void {
        if !HKHealthStore.isHealthDataAvailable() {
            throw HKManagerError.healthDataUnavailable
        }

        try await healthStore.requestAuthorization(
            toShare: [],
            read: Set(types)
        )
    }

    /// Returns quantity samples for each requested type during a date range.
    ///
    /// - Parameters:
    ///   - types: The quantity types to query.
    ///   - startDate: The beginning of the requested period.
    ///   - endDate: The end of the requested period.
    /// - Returns: One 'HealthDataSeries' for each requested quantity type.
    /// - Throws: 'HKManagerError.invalidDateRange' if the start date is
    ///   later than the end date, or an error from HealthKit.

    func readHealthData(types: [HKQuantityType], startDate: Date, endDate: Date) async throws -> [HKQuantityType: [HKQuantitySample]] {
        
        if startDate > endDate {
            throw HKManagerError.invalidDateRange
        }

        let authorizationTypes: [HKObjectType] = types.map { type in
            type as HKObjectType
        }

        try await requestReadAuth(types: authorizationTypes)
        
        // 'predicate' for a date range
        let datePredicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate
        )

        var results: [HKQuantityType: [HKQuantitySample]] = [:]
        
        // 'predicate' and query for each type that was passed
        for type in types {
            let samplePredicate = HKSamplePredicate.quantitySample(type: type, predicate: datePredicate)

            let query = HKSampleQueryDescriptor(predicates: [samplePredicate], sortDescriptors: [
                    SortDescriptor(\.endDate, order: .forward)
                ],
                limit: nil
            )

            // Running the query in the HK object (with prev auth) and populating the dict
            results[type] = try await query.result(for: healthStore)

        }

        return results
        // A dictionary with this structure: healthType: [sample1, sample2, sample3]
    }
}

