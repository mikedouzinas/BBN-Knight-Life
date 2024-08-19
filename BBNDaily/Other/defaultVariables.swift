//
//  defaultVariables.swift
//  BBNDaily
//
//  Created by Mike Veson on 7/22/22.
//

import Foundation
import UIKit

var defaultSchedules = [
    "monday":Weekday(
        L1: [
            block(name: "D", startTime: "08:15am", endTime: "09:00am", block: "D"),
            block(name: "Extended B", startTime: "09:05am", endTime: "10:10am", block: "B"),
            block(name: "Class Meeting", startTime: "10:15am", endTime: "10:30am", block: "N/A"),
            block(name: "G", startTime: "10:35am", endTime: "11:20am", block: "G"),
            block(name: "Lunch", startTime: "11:25am", endTime: "11:55am", block: "N/A"),
            block(name: "C2", startTime: "12:00pm", endTime: "12:45pm", block: "C"),
            block(name: "Extended A", startTime: "12:50pm", endTime: "01:55pm", block: "A"),
            block(name: "Community Activity", startTime: "02:00pm", endTime: "02:35pm", block: "N/A"),
            block(name: "F", startTime: "02:40pm", endTime: "03:25pm", block: "F")
        ], L2: [
            block(name: "D", startTime: "08:15am", endTime: "09:00am", block: "D"),
            block(name: "Extended B", startTime: "09:05am", endTime: "10:10am", block: "B"),
            block(name: "Class Meeting", startTime: "10:15am", endTime: "10:30am", block: "N/A"),
            block(name: "G", startTime: "10:35am", endTime: "11:20am", block: "G"),
            block(name: "C1", startTime: "11:25am", endTime: "12:10pm", block: "C"),
            block(name: "Lunch", startTime: "12:15pm", endTime: "12:45pm", block: "N/A"),
            block(name: "Extended A", startTime: "12:50pm", endTime: "01:55pm", block: "A"),
            block(name: "Community Activity", startTime: "02:00pm", endTime: "02:35pm", block: "N/A"),
            block(name: "F", startTime: "02:40pm", endTime: "03:25pm", block: "F")
        ]),
    "tuesday":Weekday(
        L1: [
            block(name: "(Optional) FACT/CAB", startTime: "07:55am", endTime: "08:45am", block: "N/A"),
            block(name: "G", startTime: "08:50am", endTime: "09:35am", block: "G"),
            block(name: "E", startTime: "09:40am", endTime: "10:25am", block: "E"),
            block(name: "Long Passing", startTime: "10:25am", endTime: "10:30am", block: "N/A"),
            block(name: "A", startTime: "10:35am", endTime: "11:20am", block: "A"),
            block(name: "Lunch", startTime: "11:25am", endTime: "11:55am", block: "N/A"),
            block(name: "F2", startTime: "12:00pm", endTime: "12:45pm", block: "F"),
            block(name: "Extended D", startTime: "12:50pm", endTime: "01:55pm", block: "D"),
            block(name: "Advisory", startTime: "02:00pm", endTime: "02:35pm", block: "N/A"),
            block(name: "B", startTime: "02:40pm", endTime: "03:25pm", block: "B")
        ], L2: [
            block(name: "(Optional) FACT/CAB", startTime: "07:55am", endTime: "08:45am", block: "N/A"),
            block(name: "G", startTime: "08:50am", endTime: "09:35am", block: "G"),
            block(name: "E", startTime: "09:40am", endTime: "10:25am", block: "E"),
            block(name: "Long Passing", startTime: "10:25am", endTime: "10:30am", block: "N/A"),
            block(name: "A", startTime: "10:35am", endTime: "11:20am", block: "A"),
            block(name: "F1", startTime: "11:25am", endTime: "12:10pm", block: "F"),
            block(name: "Lunch", startTime: "12:15pm", endTime: "12:45pm", block: "N/A"),
            block(name: "Extended D", startTime: "12:50pm", endTime: "01:55pm", block: "D"),
            block(name: "Advisory", startTime: "02:00pm", endTime: "02:35pm", block: "N/A"),
            block(name: "B", startTime: "02:40pm", endTime: "03:25pm", block: "B")
        ]),
    "wednesday":Weekday(
        L1: [
            block(name: "F", startTime: "08:15am", endTime: "09:00am", block: "F"),
            block(name: "A", startTime: "09:05am", endTime: "09:50am", block: "A"),
            block(name: "Assembly", startTime: "09:55am", endTime: "10:30am", block: "N/A"),
            block(name: "C", startTime: "10:35am", endTime: "11:20am", block: "C"),
            block(name: "Lunch", startTime: "11:25am", endTime: "11:55am", block: "N/A"),
            block(name: "E2", startTime: "12:00pm", endTime: "12:45pm", block: "E"),
            block(name: "Community Activity", startTime: "12:50pm", endTime: "01:30pm", block: "N/A")
        ], L2: [
            block(name: "F", startTime: "08:15am", endTime: "09:00am", block: "F"),
            block(name: "A", startTime: "09:05am", endTime: "09:50am", block: "A"),
            block(name: "Assembly", startTime: "09:55am", endTime: "10:30am", block: "N/A"),
            block(name: "C", startTime: "10:35am", endTime: "11:20am", block: "C"),
            block(name: "E1", startTime: "11:25am", endTime: "12:10pm", block: "E"),
            block(name: "Lunch", startTime: "12:15pm", endTime: "12:45pm", block: "N/A"),
            block(name: "Community Activity", startTime: "12:50pm", endTime: "01:30pm", block: "N/A")
        ]),
    "thursday":Weekday(
        L1: [
            block(name: "C", startTime: "08:15am", endTime: "09:00am", block: "C"),
            block(name: "Extended G", startTime: "09:05am", endTime: "10:10am", block: "G"),
            block(name: "Advisory", startTime: "10:15am", endTime: "10:30am", block: "N/A"),
            block(name: "B", startTime: "10:35am", endTime: "11:20am", block: "B"),
            block(name: "Lunch", startTime: "11:25am", endTime: "11:55am", block: "N/A"),
            block(name: "D2", startTime: "12:00pm", endTime: "12:45pm", block: "D"),
            block(name: "Extended E", startTime: "12:50pm", endTime: "01:55pm", block: "E"),
            block(name: "Community Activity", startTime: "02:00pm", endTime: "02:35pm", block: "N/A"),
            block(name: "A", startTime: "02:40pm", endTime: "03:25pm", block: "A")
        ], L2: [
            block(name: "C", startTime: "08:15am", endTime: "09:00am", block: "C"),
            block(name: "Extended G", startTime: "09:05am", endTime: "10:10am", block: "G"),
            block(name: "Advisory", startTime: "10:15am", endTime: "10:30am", block: "N/A"),
            block(name: "B", startTime: "10:35am", endTime: "11:20am", block: "B"),
            block(name: "D1", startTime: "11:25am", endTime: "12:10pm", block: "D"),
            block(name: "Lunch", startTime: "12:15pm", endTime: "12:45pm", block: "N/A"),
            block(name: "Extended E", startTime: "12:50pm", endTime: "01:55pm", block: "E"),
            block(name: "Community Activity", startTime: "02:00pm", endTime: "02:35pm", block: "N/A"),
            block(name: "A", startTime: "02:40pm", endTime: "03:25pm", block: "A")
        ]),
    "friday":Weekday(
        L1: [
            block(name: "E", startTime: "08:15am", endTime: "09:00am", block: "E"),
            block(name: "Extended F", startTime: "09:05am", endTime: "10:10am", block: "F"),
            block(name: "Long Passing", startTime: "10:10am", endTime: "10:30am", block: "N/A"),
            block(name: "D", startTime: "10:35am", endTime: "11:20am", block: "D"),
            block(name: "Lunch", startTime: "11:25am", endTime: "11:55am", block: "N/A"),
            block(name: "B2", startTime: "12:00pm", endTime: "12:45pm", block: "B"),
            block(name: "Extended C", startTime: "12:50pm", endTime: "01:55pm", block: "C"),
            block(name: "G", startTime: "02:00pm", endTime: "02:45pm", block: "G"),
            block(name: "Community Activity", startTime: "02:50pm", endTime: "03:25pm", block: "N/A")
        ], L2: [
            block(name: "E", startTime: "08:15am", endTime: "09:00am", block: "E"),
            block(name: "Extended F", startTime: "09:05am", endTime: "10:10am", block: "F"),
            block(name: "Long Passing", startTime: "10:10am", endTime: "10:30am", block: "N/A"),
            block(name: "D", startTime: "10:35am", endTime: "11:20am", block: "D"),
            block(name: "B1", startTime: "11:25am", endTime: "12:10pm", block: "B"),
            block(name: "Lunch", startTime: "12:15pm", endTime: "12:45pm", block: "N/A"),
            block(name: "Extended C", startTime: "12:50pm", endTime: "01:55pm", block: "C"),
            block(name: "G", startTime: "02:00pm", endTime: "02:45pm", block: "G"),
            block(name: "Community Activity", startTime: "02:50pm", endTime: "03:25pm", block: "N/A")
        ]),
]

var regularSchedule = [
    "monday": [],
    "tuesday": [],
    "wednesday": [],
    "thursday": [],
    "friday": []
]
