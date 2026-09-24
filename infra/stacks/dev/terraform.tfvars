# ============================================================
# Dev Stack Variable Values
# ============================================================

aws_region = "us-east-1"

# CIDR block allowed to reach the Application Load Balancer on port 80.
# Set this to your own public IP as a /32 so only you can access the ALB.
#
# Get your IP:
#   curl -s checkip.amazonaws.com
#   # then append /32, e.g. "203.0.113.42/32"
#
alb_ingress_cidr = "YOUR_IP/32"
