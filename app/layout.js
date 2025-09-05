import { Inter } from "next/font/google";
import { getSEOTags } from "@/libs/seo";
import ClientLayout from "@/components/LayoutClient";
import AppLayout from "@/components/AppLayout";
import { UserProvider } from "@/contexts/UserContext";
import { QueryProvider } from "@/contexts/QueryProvider";
import config from "@/config";
import "./globals.css";

const font = Inter({ subsets: ["latin"] });

export const viewport = {
	// Will use the primary color of your theme to show a nice theme color in the URL bar of supported browsers
	themeColor: config.colors.main,
	width: "device-width",
	initialScale: 1,
};

// This adds default SEO tags to all pages in our app.
// You can override them in each page passing params to getSOTags() function.
export const metadata = getSEOTags();

export default function RootLayout({ children }) {
	return (
		<html
			lang="en"
			data-theme={config.colors.theme}
			className={font.className}
		>
			<body>
				{/* QueryProvider provides React Query for API caching */}
				<QueryProvider>
					{/* UserProvider provides centralized user state management */}
					<UserProvider>
						{/* ClientLayout contains all the client wrappers (Crisp chat support, toast messages, tooltips, etc.) */}
						<ClientLayout>
							<AppLayout>{children}</AppLayout>
						</ClientLayout>
					</UserProvider>
				</QueryProvider>
			</body>
		</html>
	);
}
