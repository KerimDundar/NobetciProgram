# -*- coding: utf-8 -*-
import unittest
from datetime import date

from roster_logic import (
    build_next_week,
    build_title,
    build_week,
    duplicate_location_key,
    is_duplicate_location,
    next_week_dates,
    rotate_roster,
    rotate_roster_back,
)


class RosterLogicTests(unittest.TestCase):
    def test_rotate_roster_preserves_empty_slots_and_order(self):
        roster = [
            ["A", "", "C", "D", "E"],
            ["F", "G", "H", "", "J"],
            ["K", "L", "", "M", ""],
        ]

        self.assertEqual(
            rotate_roster(roster),
            [
                ["F", "", "H", "M", "J"],
                ["K", "L", "C", "", "E"],
                ["A", "G", "", "D", ""],
            ],
        )
        self.assertEqual(roster[0][0], "A")

    def test_rotate_roster_edge_cases(self):
        self.assertEqual(rotate_roster([]), [])
        self.assertEqual(rotate_roster([["A", "", "C", "", "E"]]), [["A", "", "C", "", "E"]])
        with self.assertRaises(IndexError):
            rotate_roster([["A"], ["B"]])

    def test_rotate_roster_back_reverses_rotation(self):
        roster = [
            ["A", "", "C", "D", "E"],
            ["F", "G", "H", "", "J"],
            ["K", "L", "", "M", ""],
        ]

        self.assertEqual(rotate_roster_back(rotate_roster(roster)), roster)

    def test_build_week_shape_and_copy_isolation(self):
        start = date(2026, 4, 20)
        end = date(2026, 4, 24)
        locations = ["L1"]
        roster = [["A", "B", "C", "D", "E"]]

        week = build_week(start, end, locations, roster, "S", "P")

        self.assertEqual(
            week,
            {
                "title": build_title(start, end),
                "start_date": "2026-04-20",
                "end_date": "2026-04-24",
                "school_name": "S",
                "principal_name": "P",
                "locations": ["L1"],
                "roster": [["A", "B", "C", "D", "E"]],
            },
        )
        locations[0] = "CHANGED"
        roster[0][0] = "CHANGED"
        self.assertEqual(week["locations"], ["L1"])
        self.assertEqual(week["roster"][0][0], "A")

    def test_build_next_week_matches_manual_next_week(self):
        start = date(2026, 4, 20)
        end = date(2026, 4, 24)
        locations = ["L1", "L2"]
        roster = [["A", "B", "C", "D", "E"], ["F", "G", "H", "I", "J"]]
        next_start, next_end = next_week_dates(start, end)

        self.assertEqual(
            build_next_week(start, end, locations, roster, "S", "P"),
            build_week(next_start, next_end, locations, rotate_roster(roster), "S", "P"),
        )

    def test_build_next_week_multi_step_sequence(self):
        week = build_week(
            date(2026, 4, 20),
            date(2026, 4, 24),
            ["L1", "L2", "L3"],
            [
                ["A", "", "C", "D", "E"],
                ["F", "G", "H", "", "J"],
                ["K", "L", "", "M", ""],
            ],
            "S",
            "P",
        )
        weeks = [week]
        for _ in range(4):
            week = build_next_week(
                date.fromisoformat(week["start_date"]),
                date.fromisoformat(week["end_date"]),
                week["locations"],
                week["roster"],
                week["school_name"],
                week["principal_name"],
            )
            weeks.append(week)

        self.assertEqual(
            [w["start_date"] for w in weeks],
            ["2026-04-20", "2026-04-27", "2026-05-04", "2026-05-11", "2026-05-18"],
        )
        expected_roster = weeks[0]["roster"]
        for idx in range(1, len(weeks)):
            expected_roster = rotate_roster(expected_roster)
            self.assertEqual(weeks[idx]["roster"], expected_roster)

        weeks[0]["locations"][0] = "CHANGED"
        weeks[0]["roster"][0][0] = "CHANGED"
        self.assertNotEqual(weeks[1]["locations"][0], "CHANGED")
        self.assertNotEqual(weeks[1]["roster"][0][0], "CHANGED")

    def test_duplicate_location_rules(self):
        self.assertEqual(duplicate_location_key("KAT-3"), "KAT3")
        self.assertEqual(duplicate_location_key(" KAT - 3 "), "KAT3")
        self.assertEqual(duplicate_location_key(""), "")
        self.assertTrue(is_duplicate_location("KAT-3", "KAT 3"))
        self.assertTrue(is_duplicate_location(" KAT - 3 ", "KAT-3"))
        self.assertFalse(is_duplicate_location("", "KAT 3"))
        self.assertFalse(is_duplicate_location("", ""))


if __name__ == "__main__":
    unittest.main()
