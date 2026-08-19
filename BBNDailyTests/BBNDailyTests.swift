//
//  BBNDailyTests.swift
//  BBNDailyTests
//
//  Created by Mike Veson on 9/6/21.
//
//  The Xcode template's `testExample` and `testPerformanceExample` lived here from 2021 to
//  2026 and asserted nothing. They are gone.
//
//  Worth a note rather than a silent deletion, because they are the exact failure this
//  project keeps meeting in other costumes: a check that examines nothing is worse than no
//  check at all, since it occupies the slot and reports success. For five years this target
//  could be run and would pass, which is indistinguishable from a target with real coverage
//  until somebody looks.
//
//  Real tests live in:
//    ResolveDayTests         - what day it is, which decides everything a student sees
//    FirestoreParsingTests   - surviving a malformed document instead of crashing on launch
//
//  CI runs the whole target and fails when the executed count is zero, so an empty suite
//  cannot pass quietly again.
//
