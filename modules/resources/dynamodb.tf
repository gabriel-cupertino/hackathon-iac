resource "aws_dynamodb_table" "solidarytech_volunteers" {
  name         = "SolidaryTechVolunteers"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "volunteer_id"

  attribute {
    name = "volunteer_id"
    type = "S"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-volunteers-table"
    }
  )
}
