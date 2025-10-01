import { createServiceClient } from '@/libs/supabase/server';
import { sendEmail } from '@/libs/resend';

export async function POST(request) {
  try {
    const supabase = createServiceClient();
    
    // Get users who haven't signed in for over a week
    const oneWeekAgo = new Date();
    oneWeekAgo.setDate(oneWeekAgo.getDate() - 7);
    
    const { data: inactiveUsers, error: usersError } = await supabase
      .from('profiles')
      .select(`
        id, email, first_name, last_name, last_sign_in_at,
        dogs!inner(name)
      `)
      .lt('last_sign_in_at', oneWeekAgo.toISOString())
      .not('last_sign_in_at', 'is', null)
      .not('email', 'is', null);

    if (usersError) {
      console.error('Error fetching inactive users:', usersError);
      return Response.json({ error: 'Failed to fetch inactive users' }, { status: 500 });
    }

    let emailsSent = 0;
    const errors = [];

    // Send re-engagement emails to each inactive user
    for (const user of inactiveUsers || []) {
      try {
        // Check if user has email notifications enabled
        const { data: settings } = await supabase
          .from('user_settings')
          .select('email_notifications')
          .eq('user_id', user.id)
          .single();

        if (settings && !settings.email_notifications) {
          continue; // Skip users who have disabled email notifications
        }

        // Get user's first dog name
        const userDogName = user.dogs?.[0]?.name || 'your dog';

        // Calculate days since last sign in
        const lastSignIn = new Date(user.last_sign_in_at);
        const daysSinceLastSignIn = Math.floor((Date.now() - lastSignIn.getTime()) / (1000 * 60 * 60 * 24));

        // Send re-engagement email
        await sendEmail({
          to: user.email,
          subject: `We miss you and ${userDogName}! 🐕`,
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
              <h1 style="color: #7c3aed;">We miss you, ${user.first_name || 'there'}!</h1>
              
              <p>It's been ${daysSinceLastSignIn} days since you last visited ShareSkippy, and we wanted to check in!</p>
              
              <p>Your dog ${userDogName} might be missing out on some great playdates and connections in your area. Here's what's been happening:</p>
              
              <ul>
                <li>🐕 New dogs have joined your neighborhood</li>
                <li>📅 Fresh availability has been shared</li>
                <li>💬 Messages might be waiting for you</li>
              </ul>
              
              <div style="text-align: center; margin: 30px 0;">
                <a href="${process.env.NEXT_PUBLIC_APP_URL || 'https://shareskippy.com'}/community" 
                   style="background-color: #7c3aed; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                  Come Back to ShareSkippy
                </a>
              </div>
              
              <p>We'd love to see you and ${userDogName} back in the community!</p>
              
              <p>Best regards,<br>The ShareSkippy Team 🐾</p>
            </div>
          `,
          text: `We miss you, ${user.first_name || 'there'}!

It's been ${daysSinceLastSignIn} days since you last visited ShareSkippy, and we wanted to check in!

Your dog ${userDogName} might be missing out on some great playdates and connections in your area.

Come back to ShareSkippy: ${process.env.NEXT_PUBLIC_APP_URL || 'https://shareskippy.com'}/community

We'd love to see you and ${userDogName} back in the community!

Best regards,
The ShareSkippy Team 🐾`
        });

        emailsSent++;

        // Track that re-engagement email was sent
        await supabase
          .from('user_settings')
          .upsert({
            user_id: user.id,
            re_engagement_email_sent: true,
            re_engagement_email_sent_at: new Date().toISOString()
          });

      } catch (error) {
        console.error(`Error sending re-engagement email to user ${user.id}:`, error);
        errors.push({
          userId: user.id,
          email: user.email,
          error: error.message
        });
      }
    }

    return Response.json({
      success: true,
      message: `Re-engagement emails processed`,
      emailsSent,
      usersProcessed: inactiveUsers?.length || 0,
      errors: errors.length > 0 ? errors : undefined
    });

  } catch (error) {
    console.error('Error in re-engagement emails:', error);
    return Response.json(
      { error: 'Failed to process re-engagement emails' }, 
      { status: 500 }
    );
  }
}
