from typing import List

def cutoff_leading_text(text:str, flag_list:List[str]):
    for flag in flag_list:
        search_result = text.find(flag)
        if search_result != -1:
            return text[search_result:]
        
    raise Exception("No cutoff leading text flag found in text.")

def cutoff_trailing_text(text:str, flag_list:List[str]):
    for flag in flag_list:
        search_result = text.rfind(flag)
        if search_result != -1:
            return text[:search_result]
        
    raise Exception("No cutoff trailing text flag found in text.")