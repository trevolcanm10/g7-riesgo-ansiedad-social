from ...domain.rules.weekly_classification import WeeklyClassifier


class ClassifyWeekUseCase:
    def __init__(self, classifier: WeeklyClassifier) -> None:
        self.classifier = classifier

    def execute(self, indicators: dict) -> dict:
        return self.classifier.classify_week(indicators)