# REFERENCE EXAMPLE — multi-region setup using provider aliases.
# Copy into an empty scratch folder to try it; it is not applied from the parent folder.

provider "aws" {
  region = "us-east-1"
  alias  = "us_east_1"
}

provider "aws" {
  region = "us-west-2"
  alias  = "us_west_2"
}

# AMI IDs are region-specific — use a valid AMI for each region.
resource "aws_instance" "east" {
  provider      = aws.us_east_1
  ami           = "<ami-id-in-us-east-1>"
  instance_type = "t3.micro"

  tags = {
    Name = "east-instance"
  }
}

resource "aws_instance" "west" {
  provider      = aws.us_west_2
  ami           = "<ami-id-in-us-west-2>"
  instance_type = "t3.micro"

  tags = {
    Name = "west-instance"
  }
}
