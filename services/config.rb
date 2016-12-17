# coreo_aws_vpc_vpc "${VPC_NAME}" do
#   action :find
#   cidr "${VPC_CIDR}"
#   internet_gateway true
# end
#
# coreo_aws_vpc_routetable "${PUBLIC_ROUTE_NAME}" do
#   action :find
#   vpc "${VPC_NAME}"
# end
#
# coreo_aws_vpc_subnet "${PUBLIC_SUBNET_NAME}" do
#   action :find
#   route_table "${PUBLIC_ROUTE_NAME}"
#   vpc "${VPC_NAME}"
# end

coreo_aws_ec2_securityGroups "${LAMP_NAME}-elb-sg" do
  action :sustain
  description "Open https to the world"
  vpc "${VPC_NAME}"
  allows [
             {
                 :direction => :ingress,
                 :protocol => :tcp,
                 :ports => [443,80],
                 :cidrs => ["0.0.0.0/0"],
             },{
                 :direction => :egress,
                 :protocol => :tcp,
                 :ports => ["0..65535"],
                 :cidrs => ["0.0.0.0/0"],
             }
         ]
end

coreo_aws_ec2_elb "${LAMP_NAME}-elb" do
  action :sustain
  type "public"
  vpc "${VPC_NAME}"
  subnet "${PUBLIC_SUBNET_NAME}"
  security_groups ["${LAMP_NAME}-elb-sg"]
  listeners [
                {:elb_protocol => 'http', :elb_port => 80, :to_protocol => 'http', :to_port => 8080}
            ]
  health_check_protocol 'http'
  health_check_port "8080"
  #health_check_path "/platform-services/api/v1/healthcheck"
  health_check_path "/"
end

coreo_aws_ec2_securityGroups "${LAMP_NAME}" do
  action :sustain
  description "Yum repo manager security group"
  vpc "${VPC_NAME}"
  allows [
             {
                 :direction => :ingress,
                 :protocol => :tcp,
                 :ports => ${LAMP_INGRESS_CIDR_PORTS},
      :cidrs => ${LAMP_INGRESS_CIDRS}
  },{
      :direction => :ingress,
      :protocol => :tcp,
      :ports => ${LAMP_INGRESS_GROUP_PORTS},
      :groups => ["${LAMP_NAME}-elb-sg"]
  },{
      :direction => :egress,
      :protocol => :tcp,
      :ports => ["0..65535"],
      :cidrs => ["0.0.0.0/0"]
  }
  ]
end

coreo_aws_iam_policy "${LAMP_NAME}" do
  action :sustain
  policy_name "AllowS3Yum"
  policy_document <<-EOH
{
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
          "arn:aws:s3:::${YUM_REPO_BUCKET}",
          "arn:aws:s3:::${YUM_REPO_BUCKET}/*"
      ],
      "Action": [ 
          "s3:*"
      ]
    }
  ]
}
  EOH
end

coreo_aws_iam_instance_profile "${LAMP_NAME}" do
  action :sustain
  policies ["${LAMP_NAME}"]
end

coreo_aws_ec2_instance "${LAMP_NAME}" do
  action :define
  image_id "${AWS_LINUX_AMI}"
  size "${LAMP_SIZE}"
  security_groups ["${LAMP_NAME}"]
  role "${LAMP_NAME}"
  associate_public_ip true
  upgrade_trigger "3"
  ssh_key "${LAMP_KEYPAIR}"
  disks [
            {
                :device_name => "/dev/xvda",
                :volume_size => 25
            }
        ]
end

coreo_aws_ec2_autoscaling "${LAMP_NAME}" do
  action :sustain
  minimum ${LAMP_GROUP_MINIMUM}
  maximum ${LAMP_GROUP_MAXIMUM}
  server_definition "${LAMP_NAME}"
  subnet "${PUBLIC_SUBNET_NAME}"
  elbs ["${LAMP_NAME}-elb"]
end