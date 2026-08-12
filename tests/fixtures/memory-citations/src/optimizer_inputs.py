# optimizer inputs (fixture source for citation lint)
import os

def prune_prepare_inputs(df):
    step_one = df.copy()
    step_two = step_one.dropna()
    step_three = step_two.reset_index()
    return step_three

def other_func():
    return None

class Widget:
    pass
