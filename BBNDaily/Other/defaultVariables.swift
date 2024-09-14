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

var regularSchedule = ["tuesday": [BBNDaily.Event(type: "specific", block: nil, name: nil, startTime: nil, endTime: nil, filter: Optional(["teacher"]), matchMode: Optional("any"), lunchBlock: nil, contents: Optional([BBNDaily.Event(type: "block", block: Optional("other"), name: Optional("Faculty Time"), startTime: Optional("7:55 am"), endTime: Optional("8:45 am"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil)])), BBNDaily.Event(type: "specific", block: nil, name: nil, startTime: nil, endTime: nil, filter: Optional(["9", "10", "11", "12"]), matchMode: Optional("any"), lunchBlock: nil, contents: Optional([BBNDaily.Event(type: "block", block: Optional("other"), name: Optional("Optional CAB"), startTime: Optional("7:55 am"), endTime: Optional("8:45 am"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil)])), BBNDaily.Event(type: "block", block: Optional("g"), name: Optional("G"), startTime: Optional("8:50 am"), endTime: Optional("9:35 am"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "block", block: Optional("e"), name: Optional("E"), startTime: Optional("9:40 am"), endTime: Optional("10:25 am"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "block", block: Optional("other"), name: Optional("Long Passing"), startTime: Optional("10:25 am"), endTime: Optional("10:35 am"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "block", block: Optional("f"), name: Optional("F"), startTime: Optional("10:35 am"), endTime: Optional("11:20 am"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "specific", block: nil, name: nil, startTime: nil, endTime: nil, filter: Optional(["L1"]), matchMode: Optional("any"), lunchBlock: Optional("c"), contents: Optional([BBNDaily.Event(type: "lunch", block: nil, name: nil, startTime: Optional("11:25 am"), endTime: Optional("11:55 am"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "block", block: Optional("c"), name: Optional("C2"), startTime: Optional("12:00 pm"), endTime: Optional("12:45 pm"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil)])), BBNDaily.Event(type: "specific", block: nil, name: nil, startTime: nil, endTime: nil, filter: Optional(["L2"]), matchMode: Optional("any"), lunchBlock: Optional("c"), contents: Optional([BBNDaily.Event(type: "block", block: Optional("c"), name: Optional("C1"), startTime: Optional("11:25 am"), endTime: Optional("12:10 pm"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "lunch", block: nil, name: nil, startTime: Optional("12:15 pm"), endTime: Optional("12:45 pm"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil)])), BBNDaily.Event(type: "block", block: Optional("a"), name: Optional("Extended A"), startTime: Optional("12:50 pm"), endTime: Optional("1:55 pm"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "block", block: Optional("advisory"), name: Optional("Advisory"), startTime: Optional("2:00 pm"), endTime: Optional("2:35 pm"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "block", block: Optional("b"), name: Optional("B"), startTime: Optional("2:40 pm"), endTime: Optional("3:25 pm"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil)], "wednesday": [BBNDaily.Event(type: "block", block: Optional("e"), name: Optional("E"), startTime: Optional("8:15 am"), endTime: Optional("9:00 am"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "block", block: Optional("c"), name: Optional("Extended C"), startTime: Optional("9:05 am"), endTime: Optional("10:10 am"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "block", block: Optional("other"), name: Optional("Class Meeting"), startTime: Optional("10:15 am"), endTime: Optional("10:30 am"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "block", block: Optional("d"), name: Optional("D"), startTime: Optional("10:35 am"), endTime: Optional("11:20 am"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "specific", block: nil, name: nil, startTime: nil, endTime: nil, filter: Optional(["L1"]), matchMode: Optional("any"), lunchBlock: Optional("g"), contents: Optional([BBNDaily.Event(type: "lunch", block: nil, name: nil, startTime: Optional("11:25 am"), endTime: Optional("11:55 am"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "block", block: Optional("g"), name: Optional("G2"), startTime: Optional("12:00 pm"), endTime: Optional("12:45 pm"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil)])), BBNDaily.Event(type: "specific", block: nil, name: nil, startTime: nil, endTime: nil, filter: Optional(["L2"]), matchMode: Optional("any"), lunchBlock: Optional("g"), contents: Optional([BBNDaily.Event(type: "block", block: Optional("g"), name: Optional("G1"), startTime: Optional("11:25 am"), endTime: Optional("12:10 pm"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "lunch", block: nil, name: nil, startTime: Optional("12:15 pm"), endTime: Optional("12:45 pm"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil)])), BBNDaily.Event(type: "block", block: Optional("other"), name: Optional("Community Activity"), startTime: Optional("12:50 pm"), endTime: Optional("1:35 pm"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil)], "thursday": [BBNDaily.Event(type: "block", block: Optional("d"), name: Optional("D"), startTime: Optional("8:15 am"), endTime: Optional("9:00 am"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "block", block: Optional("f"), name: Optional("Extended F"), startTime: Optional("9:05 am"), endTime: Optional("10:10 am"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "block", block: Optional("advisory"), name: Optional("Advisory"), startTime: Optional("10:15 am"), endTime: Optional("10:30 am"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "block", block: Optional("b"), name: Optional("B"), startTime: Optional("10:35 am"), endTime: Optional("11:20 am"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "specific", block: nil, name: nil, startTime: nil, endTime: nil, filter: Optional(["L1"]), matchMode: Optional("any"), lunchBlock: Optional("a"), contents: Optional([BBNDaily.Event(type: "lunch", block: nil, name: nil, startTime: Optional("11:25 am"), endTime: Optional("11:55 am"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "block", block: Optional("a"), name: Optional("A2"), startTime: Optional("12:00 pm"), endTime: Optional("12:45 pm"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil)])), BBNDaily.Event(type: "specific", block: nil, name: nil, startTime: nil, endTime: nil, filter: Optional(["L2"]), matchMode: Optional("any"), lunchBlock: Optional("a"), contents: Optional([BBNDaily.Event(type: "block", block: Optional("a"), name: Optional("A1"), startTime: Optional("11:25 am"), endTime: Optional("12:10 pm"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "lunch", block: nil, name: nil, startTime: Optional("12:15 pm"), endTime: Optional("12:45 pm"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil)])), BBNDaily.Event(type: "block", block: Optional("g"), name: Optional("Extended G"), startTime: Optional("12:50 pm"), endTime: Optional("1:55 pm"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "block", block: Optional("other"), name: Optional("Community Activity"), startTime: Optional("2:00 pm"), endTime: Optional("2:35 pm"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "block", block: Optional("e"), name: Optional("E"), startTime: Optional("2:40 pm"), endTime: Optional("3:25 pm"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil)], "friday": [BBNDaily.Event(type: "block", block: Optional("g"), name: Optional("G"), startTime: Optional("8:15 am"), endTime: Optional("9:00 am"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "block", block: Optional("b"), name: Optional("Extended B"), startTime: Optional("9:05 am"), endTime: Optional("10:10 am"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "specific", block: nil, name: nil, startTime: nil, endTime: nil, filter: Optional(["teacher"]), matchMode: Optional("any"), lunchBlock: nil, contents: Optional([BBNDaily.Event(type: "block", block: Optional("other"), name: Optional("Faculty Meeting (Long Passing)"), startTime: Optional("10:15 am"), endTime: Optional("10:30 am"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil)])), BBNDaily.Event(type: "specific", block: nil, name: nil, startTime: nil, endTime: nil, filter: Optional(["9", "10", "11", "12"]), matchMode: Optional("any"), lunchBlock: nil, contents: Optional([BBNDaily.Event(type: "block", block: Optional("other"), name: Optional("Long Passing"), startTime: Optional("10:15 am"), endTime: Optional("10:30 am"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil)])), BBNDaily.Event(type: "block", block: Optional("a"), name: Optional("A"), startTime: Optional("10:35 am"), endTime: Optional("11:20 am"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "specific", block: nil, name: nil, startTime: nil, endTime: nil, filter: Optional(["L1"]), matchMode: Optional("any"), lunchBlock: Optional("f"), contents: Optional([BBNDaily.Event(type: "lunch", block: nil, name: nil, startTime: Optional("11:25 am"), endTime: Optional("11:55 am"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "block", block: Optional("f"), name: Optional("F2"), startTime: Optional("12:00 pm"), endTime: Optional("12:45 pm"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil)])), BBNDaily.Event(type: "specific", block: nil, name: nil, startTime: nil, endTime: nil, filter: Optional(["L2"]), matchMode: Optional("any"), lunchBlock: Optional("f"), contents: Optional([BBNDaily.Event(type: "block", block: Optional("f"), name: Optional("F1"), startTime: Optional("11:25 am"), endTime: Optional("12:10 pm"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "lunch", block: nil, name: nil, startTime: Optional("12:15 pm"), endTime: Optional("12:45 pm"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil)])), BBNDaily.Event(type: "block", block: Optional("d"), name: Optional("Extended D"), startTime: Optional("12:50 pm"), endTime: Optional("1:55 pm"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "block", block: Optional("c"), name: Optional("C"), startTime: Optional("2:00 pm"), endTime: Optional("2:45 pm"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "block", block: Optional("other"), name: Optional("Community Activity"), startTime: Optional("2:50 pm"), endTime: Optional("3:25 pm"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil)], "monday": [BBNDaily.Event(type: "block", block: Optional("a"), name: Optional("A"), startTime: Optional("8:15 am"), endTime: Optional("9:00 am"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "block", block: Optional("b"), name: Optional("B"), startTime: Optional("9:05 am"), endTime: Optional("9:50 am"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "block", block: Optional("other"), name: Optional("Assembly/Special Programming"), startTime: Optional("9:55 am"), endTime: Optional("10:30 am"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "block", block: Optional("c"), name: Optional("C"), startTime: Optional("10:35 am"), endTime: Optional("11:20 am"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "specific", block: nil, name: nil, startTime: nil, endTime: nil, filter: Optional(["L1"]), matchMode: Optional("any"), lunchBlock: Optional("d"), contents: Optional([BBNDaily.Event(type: "lunch", block: nil, name: nil, startTime: Optional("11:25 am"), endTime: Optional("11:55 am"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "block", block: Optional("d"), name: Optional("D2"), startTime: Optional("12:00 pm"), endTime: Optional("12:45 pm"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil)])), BBNDaily.Event(type: "specific", block: nil, name: nil, startTime: nil, endTime: nil, filter: Optional(["L2"]), matchMode: Optional("any"), lunchBlock: Optional("d"), contents: Optional([BBNDaily.Event(type: "block", block: Optional("d"), name: Optional("D1"), startTime: Optional("11:25 am"), endTime: Optional("12:10 pm"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "lunch", block: nil, name: nil, startTime: Optional("12:15 pm"), endTime: Optional("12:45 pm"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil)])), BBNDaily.Event(type: "block", block: Optional("e"), name: Optional("Extended E"), startTime: Optional("12:50 pm"), endTime: Optional("1:55 pm"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "block", block: Optional("other"), name: Optional("Community Activity"), startTime: Optional("2:00 pm"), endTime: Optional("2:35 pm"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil), BBNDaily.Event(type: "block", block: Optional("f"), name: Optional("F"), startTime: Optional("2:40 pm"), endTime: Optional("3:25 pm"), filter: nil, matchMode: nil, lunchBlock: nil, contents: nil)]]
