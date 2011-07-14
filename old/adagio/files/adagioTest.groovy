import javax.naming.Context
import javax.naming.InitialContext
import javax.rmi.PortableRemoteObject

import adagio.entity.merchant.MerchantVALUE
import adagio.entity.organization.OrganizationVALUE
import adagio.session.login.UserSession
import adagio.session.login.UserSessionHOME
import adagio.session.document.addupdate.*
import adagio.shared.AppContext
import adagio.entity.geography.Address

println "Setting system properties ..."
System.setProperty( Context.INITIAL_CONTEXT_FACTORY, 
                    "org.jnp.interfaces.NamingContextFactory" );
System.setProperty( Context.PROVIDER_URL, "jnp://${args[0]}:1099" );

println "Getting initial context ..."
context = new InitialContext();

println "Initializing Address with ${context} ..."
Address.init(context)

println "Get UserSessionHOME ..."
userSessionHOME =
   PortableRemoteObject.narrow( context.lookup( "adagio/session/login/UserSession" ),
                                UserSessionHOME.class );

println "Creating MerchantVALUE ..."
oMerchantVALUE = new MerchantVALUE();
oMerchantVALUE.MerchantID = "0";

println "Getting UserSession ..."
userSession = userSessionHOME.create( new AppContext( oMerchantVALUE ), "" );

if (args[1].equals("abc-p1-srv-1")) {
   username = "jdoe"
   password = "90406147"
   document = "100040    "
} else {
   username = "fabian"
   password = "fabianfabian"
   document = "63        "
}

println "Logging in as $username ..."
userSession.login( username, password );   // has R=G, W=G resourceid=67479

println "Getting DocumentAddUpdateSession ..."
docSession = userSession.getDocumentAddUpdateSession();

println "Opening old document view ..."
docSession.open( document );
docSession.close();

println "Document closed."
