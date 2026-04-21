# ============================================================================
# NETWORK LOAD BALANCER INTERNO
# O API Gateway publica as rotas e o VPC Link alcança este NLB
# ============================================================================

resource "aws_lb" "interno" {
  name               = "${local.project_name}-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = aws_subnet.private[*].id

  enable_cross_zone_load_balancing = true

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-nlb"
  })
}

resource "aws_lb_target_group" "microservicos" {
  for_each = local.servicos_gateway

  name        = substr("${local.project_name}-${each.key}-tg", 0, 32)
  port        = 8080
  protocol    = "TCP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    protocol            = "TCP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
  }

  tags = merge(local.common_tags, {
    Name    = "${local.project_name}-${each.key}-tg"
    Service = each.key
  })
}

resource "aws_lb_listener" "microservicos" {
  for_each = local.servicos_gateway

  load_balancer_arn = aws_lb.interno.arn
  port              = each.value.listener_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.microservicos[each.key].arn
  }
}

