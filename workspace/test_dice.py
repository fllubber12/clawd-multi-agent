import unittest
import dice

class TestDice(unittest.TestCase):
    def test_roll_in_range(self):
        result = dice.roll(6)
        self.assertTrue(1 <= result <= 6)

    def test_roll_sides_1(self):
        result = dice.roll(1)
        self.assertEqual(result, 1)

    def test_roll_randomness(self):
        results = [dice.roll(6) for _ in range(10)]
        self.assertTrue(len(set(results)) > 1)

if __name__ == '__main__':
    unittest.main()
