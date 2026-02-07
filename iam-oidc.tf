# GitHub OIDC Federation (Alternative to long-term credentials)
# This allows GitHub Actions to authenticate with AWS using short-term credentials
# More secure than access keys - no secrets to manage or rotate
# Uncomment and use this instead of iam-cicd.tf for production

/*
# GitHub OIDC Identity Provider
# Only needed once per AWS account - check if it exists first
resource "aws_iam_openid_connect_provider" "github" {
  provider = aws.primary
  url      = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "6938fd4e98bab03faadb97b34396831e3780aea1"  # GitHub's OIDC thumbprint
  ]

  tags = local.common_tags
}

# IAM Role for GitHub Actions OIDC
resource "aws_iam_role" "github_actions" {
  provider = aws.primary
  name     = "${local.app_name}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:apitanga/serverless-ssr-pattern:ref:refs/heads/main",
              "repo:apitanga/serverless-ssr-pattern:pull_request"
            ]
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# Attach the same policy as the CI/CD user
resource "aws_iam_role_policy_attachment" "github_actions" {
  provider   = aws.primary
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.cicd.arn
}

# Output the role ARN for GitHub Actions workflow
output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions OIDC"
  value       = aws_iam_role.github_actions.arn
}

output "oidc_setup_instructions" {
  description = "Instructions for OIDC-based GitHub Actions authentication"
  value       = <<-EOT
    
    🔐 GitHub OIDC Federation Configured
    
    Update your GitHub Actions workflow to use OIDC:
    
    jobs:
      deploy:
        permissions:
          id-token: write  # Required for OIDC
          contents: read
        steps:
          - name: Configure AWS Credentials
            uses: aws-actions/configure-aws-credentials@v4
            with:
              role-to-assume: ${aws_iam_role.github_actions.arn}
              aws-region: us-east-1
    
    No secrets needed! AWS credentials are temporary and auto-rotated.
    
  EOT
}
*/
