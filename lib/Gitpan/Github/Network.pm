use MooseX::Declare;

class Gitpan::Github::Network
  extends Net::GitHub::V2::Network
  with Gitpan::Github::ResponseReader
  with Gitpan::Github::CanBackoff
{
   override network_meta {
       my $result = super;

       
   }
}
