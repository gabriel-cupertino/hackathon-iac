resource "aws_sqs_queue" "solidary_donations" {
  name                      = "solidary-donations"
  delay_seconds             = 0
  max_message_size          = 4096
  message_retention_seconds = 86400
  receive_wait_time_seconds = 0

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-donations-sqs"
    }
  )
}
