//
//  ProwlSessionRedactor.swift
//  ProwlCore
//

import Foundation

public enum ProwlSessionRedactor {
    public static func redact(_ logs: [NetworkLog], masker: SensitiveDataMasker = SensitiveDataMasker()) -> [NetworkLog] {
        logs.map { redact($0, masker: masker) }
    }

    public static func redact(_ log: NetworkLog, masker: SensitiveDataMasker = SensitiveDataMasker()) -> NetworkLog {
        NetworkLog(
            id: log.id,
            requestID: log.requestID,
            url: log.url,
            method: log.method,
            requestHeaders: masker.mask(headers: log.requestHeaders),
            requestBody: masker.mask(body: log.requestBody?.data, contentType: log.requestBody?.contentType),
            responseHeaders: masker.mask(headers: log.responseHeaders),
            responseBody: masker.mask(body: log.responseBody?.data, contentType: log.responseBody?.contentType),
            statusCode: log.statusCode,
            startedAt: log.startedAt,
            duration: log.duration,
            timeoutInterval: log.timeoutInterval,
            cachePolicy: log.cachePolicy,
            errorDescription: log.errorDescription,
            endpointRateAlertTriggered: log.endpointRateAlertTriggered,
            hostIp: log.hostIp,
            networkProtocol: log.networkProtocol,
            timing: log.timing,
            requestMultipartParts: log.requestMultipartParts,
            responseMultipartParts: log.responseMultipartParts,
            requestRewritten: log.requestRewritten,
            responseMocked: log.responseMocked
        )
    }
}
