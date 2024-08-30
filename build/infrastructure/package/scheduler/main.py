"""This script stop and start aws resources."""
import os

from .instance_handler import InstanceScheduler


def lambda_handler(event, context):
    """Main function entrypoint for lambda.

    Stop AWS resources:
    - instance ec2
    """
    # Retrieve variables from aws lambda ENVIRONMENT
    schedule_action = os.getenv("SCHEDULE_ACTION")
    aws_regions = os.getenv("AWS_REGIONS").replace(" ", "").split(",")
    format_tags = [{"Key": os.getenv("TAG_KEY"), "Values": [os.getenv("TAG_VALUE")]}]

    _strategy = {
        InstanceScheduler: os.getenv("EC2_SCHEDULE"),
    }

    for service, to_schedule in _strategy.items():
        if strtobool(to_schedule):
            for aws_region in aws_regions:
                strategy = service(aws_region)
                getattr(strategy, schedule_action)(aws_tags=format_tags)


def strtobool(value: str) -> bool:
    """Convert string to boolean."""
    return value.lower() in ("yes", "true", "t", "1")
